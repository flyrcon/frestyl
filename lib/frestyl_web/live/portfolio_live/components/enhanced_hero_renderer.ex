# File: lib/frestyl_web/live/portfolio_live/components/enhanced_hero_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedHeroRenderer do
  @moduledoc """
  PATCH 2: Enhanced hero section rendering with proper video/social precedence logic.
  Video takes precedence, social links display nearby, smart fallbacks when neither present.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  # ============================================================================
  # MAIN HERO SECTION RENDERER
  # ============================================================================

  def render_enhanced_hero(portfolio, sections, color_scheme \\ "blue") do
    # Extract hero content from portfolio and sections
    hero_data = extract_hero_data(portfolio, sections)

    # Determine hero layout based on available content
    hero_layout = determine_hero_layout(hero_data)

    # Get theme-based styling
    theme_config = get_hero_theme_config(portfolio.theme || "professional", color_scheme)

    # Render based on determined layout
    case hero_layout do
      :video_primary -> render_video_primary_hero(hero_data, theme_config)
      :social_primary -> render_social_primary_hero(hero_data, theme_config)
      :content_only -> render_content_only_hero(hero_data, theme_config)
      :minimal -> render_minimal_hero(hero_data, theme_config)
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

  # ============================================================================
  # VIDEO-PRIMARY HERO LAYOUT
  # ============================================================================

  defp render_video_primary_hero(hero_data, theme_config) do
    video = hero_data.video.primary_video
    profile = hero_data.profile.data
    social = hero_data.social

    """
    <section class="hero-section video-primary #{theme_config.background_class}">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid lg:grid-cols-2 gap-12 items-center min-h-[600px] py-12">

          <!-- Video Section (Left/Primary) -->
          <div class="video-container order-1 lg:order-1">
            <div class="relative">
              #{render_video_player(video, theme_config)}

              <!-- Video Overlay Info -->
              <div class="absolute bottom-4 left-4 right-4 bg-black bg-opacity-70 text-white p-4 rounded-lg backdrop-blur-sm">
                <h3 class="font-semibold text-lg">#{video.title}</h3>
                <p class="text-sm text-gray-200">Portfolio Introduction</p>
              </div>
            </div>
          </div>

          <!-- Profile Content (Right/Secondary) -->
          <div class="profile-content order-2 lg:order-2">
            <div class="text-center lg:text-left">
              #{if profile.name != "", do: "<h1 class='text-4xl lg:text-5xl font-bold #{theme_config.text_primary} mb-4'>#{profile.name}</h1>", else: ""}
              #{if profile.headline != "", do: "<h2 class='text-xl lg:text-2xl #{theme_config.text_secondary} mb-6'>#{profile.headline}</h2>", else: ""}
              #{if profile.tagline != "", do: "<p class='text-lg #{theme_config.text_muted} mb-6'>#{profile.tagline}</p>", else: ""}
              #{if profile.summary != "", do: "<p class='#{theme_config.text_body} leading-relaxed mb-8'>#{String.slice(profile.summary, 0, 200)}#{if String.length(profile.summary) > 200, do: "...", else: ""}</p>", else: ""}

              <!-- Social Links Bar (Below Video Hero) -->
              #{if social.has_social, do: render_social_links_bar(social, theme_config), else: ""}

              <!-- Call to Action -->
              <div class="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start mt-8">
                <button class="#{theme_config.primary_button} px-8 py-3 rounded-lg font-semibold transition-colors">
                  View Portfolio
                </button>
                <button class="#{theme_config.secondary_button} px-8 py-3 rounded-lg font-semibold transition-colors">
                  Contact Me
                </button>
              </div>
            </div>
          </div>

        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # SOCIAL-PRIMARY HERO LAYOUT
  # ============================================================================

  defp render_social_primary_hero(hero_data, theme_config) do
    profile = hero_data.profile.data
    social = hero_data.social
    contact = hero_data.contact

    """
    <section class="hero-section social-primary #{theme_config.background_class}">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center py-16 lg:py-24">

          <!-- Avatar/Profile Image -->
          #{if profile.avatar_url != "", do: render_profile_avatar(profile.avatar_url, theme_config), else: render_default_avatar(profile.name, theme_config)}

          <!-- Profile Content -->
          <div class="profile-content mt-8">
            #{if profile.name != "", do: "<h1 class='text-4xl lg:text-6xl font-bold #{theme_config.text_primary} mb-6'>#{profile.name}</h1>", else: ""}
            #{if profile.headline != "", do: "<h2 class='text-xl lg:text-3xl #{theme_config.text_secondary} mb-8'>#{profile.headline}</h2>", else: ""}
            #{if profile.tagline != "", do: "<p class='text-lg lg:text-xl #{theme_config.text_muted} mb-8 max-w-3xl mx-auto'>#{profile.tagline}</p>", else: ""}
            #{if profile.summary != "", do: "<p class='#{theme_config.text_body} leading-relaxed mb-12 max-w-4xl mx-auto text-lg'>#{profile.summary}</p>", else: ""}
          </div>

          <!-- Prominent Social Links -->
          #{render_prominent_social_links(social, theme_config)}

          <!-- Contact Information -->
          #{if has_contact_info?(contact), do: render_contact_bar(contact, theme_config), else: ""}

        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # CONTENT-ONLY HERO LAYOUT
  # ============================================================================

  defp render_content_only_hero(hero_data, theme_config) do
    profile = hero_data.profile.data
    social = hero_data.social

    """
    <section class="hero-section content-only #{theme_config.background_class}">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center py-16 lg:py-20">

          #{if profile.avatar_url != "", do: render_profile_avatar(profile.avatar_url, theme_config), else: ""}

          <div class="profile-content #{if profile.avatar_url != "", do: "mt-8", else: ""}">
            #{if profile.name != "", do: "<h1 class='text-4xl lg:text-5xl font-bold #{theme_config.text_primary} mb-6'>#{profile.name}</h1>", else: ""}
            #{if profile.headline != "", do: "<h2 class='text-xl lg:text-2xl #{theme_config.text_secondary} mb-6'>#{profile.headline}</h2>", else: ""}
            #{if profile.tagline != "", do: "<p class='text-lg #{theme_config.text_muted} mb-8 max-w-3xl mx-auto'>#{profile.tagline}</p>", else: ""}
            #{if profile.summary != "", do: "<div class='#{theme_config.text_body} leading-relaxed mb-10 max-w-4xl mx-auto text-lg'><p>#{profile.summary}</p></div>", else: ""}

            <!-- Action Buttons -->
            <div class="flex flex-col sm:flex-row gap-4 justify-center mb-8">
              <button class="#{theme_config.primary_button} px-8 py-3 rounded-lg font-semibold transition-colors">
                View My Work
              </button>
              <button class="#{theme_config.secondary_button} px-8 py-3 rounded-lg font-semibold transition-colors">
                Get In Touch
              </button>
            </div>

            <!-- Social Links (if available) -->
            #{if social.has_social, do: render_social_links_bar(social, theme_config), else: ""}
          </div>

        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # MINIMAL HERO LAYOUT
  # ============================================================================

  defp render_minimal_hero(hero_data, theme_config) do
    portfolio = hero_data.portfolio

    """
    <section class="hero-section minimal #{theme_config.background_class}">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center py-12 lg:py-16">

          <h1 class="text-3xl lg:text-4xl font-bold #{theme_config.text_primary} mb-4">
            #{portfolio.title}
          </h1>

          #{if portfolio.description && portfolio.description != "", do: "<p class='text-lg #{theme_config.text_body} leading-relaxed max-w-2xl mx-auto mb-8'>#{portfolio.description}</p>", else: ""}

          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="#{theme_config.primary_button} px-6 py-3 rounded-lg font-semibold transition-colors">
              Explore Portfolio
            </button>
          </div>

        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # COMPONENT RENDERERS
  # ============================================================================

  defp render_video_player(video, theme_config) do
    case video.type do
      :youtube -> render_youtube_embed(video.url, theme_config)
      :vimeo -> render_vimeo_embed(video.url, theme_config)
      :direct -> render_direct_video(video.url, theme_config)
      _ -> render_video_placeholder(video.title, theme_config)
    end
  end

  defp render_youtube_embed(url, theme_config) do
    embed_id = extract_youtube_id(url)
    """
    <div class="aspect-video bg-gray-900 rounded-xl overflow-hidden shadow-2xl">
      <iframe
        src="https://www.youtube.com/embed/#{embed_id}?rel=0&modestbranding=1"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
        class="w-full h-full">
      </iframe>
    </div>
    """
  end

  defp render_vimeo_embed(url, theme_config) do
    embed_id = extract_vimeo_id(url)
    """
    <div class="aspect-video bg-gray-900 rounded-xl overflow-hidden shadow-2xl">
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

  defp render_direct_video(url, theme_config) do
    """
    <div class="aspect-video bg-gray-900 rounded-xl overflow-hidden shadow-2xl">
      <video controls class="w-full h-full object-cover">
        <source src="#{url}" type="video/mp4">
        <source src="#{url}" type="video/webm">
        <source src="#{url}" type="video/ogg">
        Your browser does not support the video tag.
      </video>
    </div>
    """
  end

  defp render_video_placeholder(title, theme_config) do
    """
    <div class="aspect-video #{theme_config.card_background} rounded-xl border-2 border-dashed #{theme_config.border_color} flex items-center justify-center">
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

  defp render_profile_avatar(avatar_url, theme_config) do
    """
    <div class="avatar-container mb-6">
      <img src="#{avatar_url}" alt="Profile" class="w-32 h-32 lg:w-40 lg:h-40 rounded-full mx-auto object-cover shadow-xl ring-4 #{theme_config.avatar_ring}">
    </div>
    """
  end

  defp render_default_avatar(name, theme_config) do
    initials = name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()

    """
    <div class="avatar-container mb-6">
      <div class="w-32 h-32 lg:w-40 lg:h-40 #{theme_config.avatar_background} rounded-full mx-auto flex items-center justify-center shadow-xl ring-4 #{theme_config.avatar_ring}">
        <span class="text-2xl lg:text-3xl font-bold #{theme_config.avatar_text}">#{initials}</span>
      </div>
    </div>
    """
  end

  defp render_social_links_bar(social, theme_config) do
    social_items = Enum.map(social.links, fn {platform, url} ->
      icon = get_social_icon(platform)
      platform_name = format_platform_name(platform)

      """
      <a href="#{url}" target="_blank" rel="noopener noreferrer"
         class="#{theme_config.social_link} hover:#{theme_config.social_link_hover} p-3 rounded-lg transition-all duration-200 flex items-center space-x-2"
         title="#{platform_name}">
        #{icon}
        <span class="hidden sm:inline font-medium">#{platform_name}</span>
      </a>
      """
    end)

    """
    <div class="social-links-bar">
      <div class="flex flex-wrap justify-center gap-3 mt-6">
        #{Enum.join(social_items, "")}
      </div>
    </div>
    """
  end

  defp render_prominent_social_links(social, theme_config) do
    social_items = Enum.map(social.links, fn {platform, url} ->
      icon = get_social_icon(platform)
      platform_name = format_platform_name(platform)

      """
      <a href="#{url}" target="_blank" rel="noopener noreferrer"
         class="#{theme_config.prominent_social} hover:#{theme_config.prominent_social_hover} p-4 rounded-xl transition-all duration-300 flex flex-col items-center space-y-2 min-w-[120px]"
         title="Connect on #{platform_name}">
        <div class="text-2xl">#{icon}</div>
        <span class="font-semibold text-sm">#{platform_name}</span>
      </a>
      """
    end)

    """
    <div class="prominent-social-links mb-12">
      <h3 class="text-lg #{theme_config.text_secondary} mb-6">Connect With Me</h3>
      <div class="flex flex-wrap justify-center gap-4">
        #{Enum.join(social_items, "")}
      </div>
    </div>
    """
  end

  defp render_contact_bar(contact, theme_config) do
    contact_items = []

    if contact.email != "" do
      contact_items = ["<a href='mailto:#{contact.email}' class='#{theme_config.contact_link} hover:#{theme_config.contact_link_hover} flex items-center space-x-2 transition-colors'><svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z'></path></svg><span>#{contact.email}</span></a>" | contact_items]
    end

    if contact.phone != "" do
      contact_items = ["<a href='tel:#{contact.phone}' class='#{theme_config.contact_link} hover:#{theme_config.contact_link_hover} flex items-center space-x-2 transition-colors'><svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z'></path></svg><span>#{contact.phone}</span></a>" | contact_items]
    end

    if contact.location != "" do
      contact_items = ["<div class='#{theme_config.contact_item} flex items-center space-x-2'><svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z'></path><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M15 11a3 3 0 11-6 0 3 3 0 016 0z'></path></svg><span>#{contact.location}</span></div>" | contact_items]
    end

    if length(contact_items) > 0 do
      """
      <div class="contact-bar mt-8 pt-8 border-t #{theme_config.border_color}">
        <div class="flex flex-wrap justify-center gap-6">
          #{Enum.join(Enum.reverse(contact_items), "")}
        </div>
      </div>
      """
    else
      ""
    end
  end

  # ============================================================================
  # THEME CONFIGURATION
  # ============================================================================

  defp get_hero_theme_config(theme, color_scheme) do
    base_colors = get_color_scheme_colors(color_scheme)

    case theme do
      "professional" -> %{
        background_class: "bg-gradient-to-br from-slate-50 to-white",
        text_primary: "text-gray-900",
        text_secondary: "text-gray-700",
        text_muted: "text-gray-600",
        text_body: "text-gray-700",
        primary_button: "bg-#{color_scheme}-600 hover:bg-#{color_scheme}-700 text-white",
        secondary_button: "border-2 border-#{color_scheme}-600 text-#{color_scheme}-600 hover:bg-#{color_scheme}-600 hover:text-white",
        card_background: "bg-white",
        border_color: "border-gray-200",
        avatar_ring: "ring-#{color_scheme}-500",
        avatar_background: "bg-#{color_scheme}-500",
        avatar_text: "text-white",
        social_link: "bg-gray-100 text-gray-700",
        social_link_hover: "bg-#{color_scheme}-500 text-white",
        prominent_social: "bg-white border-2 border-gray-200 text-gray-700",
        prominent_social_hover: "border-#{color_scheme}-500 bg-#{color_scheme}-50",
        contact_link: "text-gray-600",
        contact_link_hover: "text-#{color_scheme}-600",
        contact_item: "text-gray-600"
      }

      "creative" -> %{
        background_class: "bg-gradient-to-br from-purple-50 via-pink-50 to-orange-50",
        text_primary: "text-gray-900",
        text_secondary: "text-purple-700",
        text_muted: "text-purple-600",
        text_body: "text-gray-700",
        primary_button: "bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white",
        secondary_button: "border-2 border-purple-600 text-purple-600 hover:bg-purple-600 hover:text-white",
        card_background: "bg-white",
        border_color: "border-purple-200",
        avatar_ring: "ring-purple-500",
        avatar_background: "bg-gradient-to-br from-purple-500 to-pink-500",
        avatar_text: "text-white",
        social_link: "bg-purple-100 text-purple-700",
        social_link_hover: "bg-purple-500 text-white",
        prominent_social: "bg-white border-2 border-purple-200 text-purple-700",
        prominent_social_hover: "border-purple-500 bg-purple-50",
        contact_link: "text-purple-600",
        contact_link_hover: "text-purple-700",
        contact_item: "text-purple-600"
      }

      "minimal" -> %{
        background_class: "bg-white",
        text_primary: "text-gray-900",
        text_secondary: "text-gray-700",
        text_muted: "text-gray-500",
        text_body: "text-gray-600",
        primary_button: "bg-gray-900 hover:bg-gray-800 text-white",
        secondary_button: "border-2 border-gray-900 text-gray-900 hover:bg-gray-900 hover:text-white",
        card_background: "bg-gray-50",
        border_color: "border-gray-200",
        avatar_ring: "ring-gray-400",
        avatar_background: "bg-gray-700",
        avatar_text: "text-white",
        social_link: "bg-gray-100 text-gray-600",
        social_link_hover: "bg-gray-900 text-white",
        prominent_social: "bg-white border-2 border-gray-200 text-gray-600",
        prominent_social_hover: "border-gray-900 bg-gray-50",
        contact_link: "text-gray-500",
        contact_link_hover: "text-gray-900",
        contact_item: "text-gray-500"
      }

      "modern" -> %{
        background_class: "bg-gradient-to-br from-blue-50 to-indigo-50",
        text_primary: "text-gray-900",
        text_secondary: "text-blue-700",
        text_muted: "text-blue-600",
        text_body: "text-gray-700",
        primary_button: "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white",
        secondary_button: "border-2 border-blue-600 text-blue-600 hover:bg-blue-600 hover:text-white",
        card_background: "bg-white",
        border_color: "border-blue-200",
        avatar_ring: "ring-blue-500",
        avatar_background: "bg-gradient-to-br from-blue-500 to-indigo-500",
        avatar_text: "text-white",
        social_link: "bg-blue-100 text-blue-700",
        social_link_hover: "bg-blue-500 text-white",
        prominent_social: "bg-white border-2 border-blue-200 text-blue-700",
        prominent_social_hover: "border-blue-500 bg-blue-50",
        contact_link: "text-blue-600",
        contact_link_hover: "text-blue-700",
        contact_item: "text-blue-600"
      }

      _ -> %{
        background_class: "bg-gray-50",
        text_primary: "text-gray-900",
        text_secondary: "text-gray-700",
        text_muted: "text-gray-600",
        text_body: "text-gray-700",
        primary_button: "bg-blue-600 hover:bg-blue-700 text-white",
        secondary_button: "border-2 border-blue-600 text-blue-600 hover:bg-blue-600 hover:text-white",
        card_background: "bg-white",
        border_color: "border-gray-200",
        avatar_ring: "ring-blue-500",
        avatar_background: "bg-blue-500",
        avatar_text: "text-white",
        social_link: "bg-gray-100 text-gray-700",
        social_link_hover: "bg-blue-500 text-white",
        prominent_social: "bg-white border-2 border-gray-200 text-gray-700",
        prominent_social_hover: "border-blue-500 bg-blue-50",
        contact_link: "text-gray-600",
        contact_link_hover: "text-blue-600",
        contact_item: "text-gray-600"
      }
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
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

  defp get_color_scheme_colors(scheme) do
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

  defp get_social_icon(platform) do
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
          <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"></path>
        </svg>
        """

      "website" ->
        """
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9 3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"></path>
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
end
