# lib/frestyl_web/live/portfolio_live/components/enhanced_section_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer do
  @moduledoc """
  Enhanced section renderer with Frestyl design philosophy:
  - No inside borders on cards
  - Clean shadows and gradients
  - Smooth hover effects
  - Professional spacing
  - Mobile-first responsive design
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.EnhancedSectionSystem

  def render(assigns) do
    ~H"""
    <div class="portfolio-section-container"
         data-section-type={@section.section_type}
         data-section-id={@section.id}>

      <!-- Section Header -->
      <div class="section-header">
        <div class="header-content">
          <div class="header-info">
            <h3 class="section-title"><%= @section.title %></h3>
          </div>

          <%= if @show_actions do %>
            <div class="header-actions">
              <button phx-click="edit_section"
                      phx-value-section_id={@section.id}
                      class="action-button edit-button">
                <svg class="button-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>
              <div class="relative">
                <button phx-click="toggle_section_menu"
                        phx-value-section_id={@section.id}
                        class="action-button menu-button">
                  <svg class="button-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
                  </svg>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Section Content (Scrollable) -->
      <div class="section-content">
        <%= render_section_content(@section, assigns) %>
      </div>

      <!-- Section Footer (if needed) -->
      <%= if has_footer_content?(@section) do %>
        <div class="section-footer">
          <%= render_section_footer(@section, assigns) %>
        </div>
      <% end %>

      <!-- Enhanced CSS Styles -->
      <style>
        .portfolio-section-container {
          background: white;
          border-radius: 16px;
          box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
          transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
          overflow: hidden;
          border: 1px solid rgba(226, 232, 240, 0.6);
          height: auto;
          min-height: 320px;
          display: flex;
          flex-direction: column;
        }

        .portfolio-section-container:hover {
          transform: translateY(-4px);
          box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
          border-color: rgba(59, 130, 246, 0.3);
        }

        .section-header {
          background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
          padding: 1.5rem;
          border-bottom: 1px solid rgba(226, 232, 240, 0.8);
          flex-shrink: 0;
        }

        .header-content {
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .header-info {
          display: flex;
          align-items: center;
          flex: 1;
        }

        .section-title {
          font-size: 1.5rem;
          font-weight: 700;
          color: #1f2937;
          margin: 0;
          line-height: 1.2;
        }

        .header-actions {
          display: flex;
          align-items: center;
          gap: 0.5rem;
        }

        .action-button {
          width: 2rem;
          height: 2rem;
          border-radius: 8px;
          border: none;
          background: white;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: all 0.2s ease;
          cursor: pointer;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        .action-button:hover {
          background: #f3f4f6;
          transform: translateY(-1px);
          box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
        }

        .button-icon {
          width: 1rem;
          height: 1rem;
          color: #6b7280;
        }

        .edit-button:hover .button-icon {
          color: #3b82f6;
        }

        .menu-button:hover .button-icon {
          color: #6b7280;
        }

        .section-content {
          flex: 1;
          padding: 1.5rem;
          overflow-y: auto;
          scrollbar-width: thin;
          scrollbar-color: #cbd5e1 transparent;
        }

        .section-content::-webkit-scrollbar {
          width: 6px;
        }

        .section-content::-webkit-scrollbar-track {
          background: transparent;
        }

        .section-content::-webkit-scrollbar-thumb {
          background: #cbd5e1;
          border-radius: 3px;
        }

        .section-content::-webkit-scrollbar-thumb:hover {
          background: #94a3b8;
        }

        .section-footer {
          background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
          padding: 1rem 1.5rem;
          border-top: 1px solid rgba(226, 232, 240, 0.8);
          flex-shrink: 0;
        }

        /* Content-specific styles */
        .empty-state {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 3rem 1rem;
          text-align: center;
          min-height: 200px;
        }

        .empty-icon {
          width: 3rem;
          height: 3rem;
          color: #d1d5db;
          margin-bottom: 1rem;
        }

        .empty-message {
          color: #6b7280;
          font-size: 0.875rem;
          font-weight: 500;
        }

        /* Mobile responsiveness */
        @media (max-width: 768px) {
          .portfolio-section-container {
            border-radius: 12px;
            min-height: 280px;
          }

          .section-header {
            padding: 1rem;
          }

          .section-content {
            padding: 1rem;
          }

          .section-title {
            font-size: 1.25rem;
          }

          .action-button {
            width: 1.75rem;
            height: 1.75rem;
          }

          .button-icon {
            width: 0.875rem;
            height: 0.875rem;
          }
        }
      </style>
    </div>
    """
  end

  # Main content renderer - delegates to specific section type renderers
  defp render_section_content(section, assigns) do
    content = section.content || %{}
    section_type = to_string(section.section_type)

    case section_type do
      "hero" -> render_hero_content(content, assigns)
      "intro" -> render_intro_content(content, assigns)
      "experience" -> render_experience_content(content, assigns)
      "education" -> render_education_content(content, assigns)
      "skills" -> render_skills_content(content, assigns)
      "projects" -> render_projects_content(content, assigns)
      "contact" -> render_contact_content(content, assigns)
      "testimonials" -> render_testimonials_content(content, assigns)
      "services" -> render_services_content(content, assigns)
      _ -> render_default_content(content, assigns)
    end
  end

  # Hero Section Renderer
  defp render_hero_content(content, _assigns) do
    assigns = %{content: content}

    ~H"""
    <div class="hero-content">
      <%= if Map.get(@content, "video_url") && Map.get(@content, "video_type") != "none" do %>
        <div class="video-container">
          <%= case Map.get(@content, "video_type") do %>
            <% "youtube" -> %>
              <iframe src={"https://www.youtube.com/embed/#{extract_youtube_id(Map.get(@content, "video_url"))}"}
                      class="video-frame" frameborder="0" allowfullscreen></iframe>
            <% "vimeo" -> %>
              <iframe src={"https://player.vimeo.com/video/#{extract_vimeo_id(Map.get(@content, "video_url"))}"}
                      class="video-frame" frameborder="0" allowfullscreen></iframe>
            <% _ -> %>
              <video controls class="video-frame">
                <source src={Map.get(@content, "video_url")} type="video/mp4">
                Your browser does not support the video tag.
              </video>
          <% end %>
        </div>
      <% end %>

      <div class="text-content">
        <%= if Map.get(@content, "headline") do %>
          <h1 class="hero-headline"><%= Map.get(@content, "headline") %></h1>
        <% end %>

        <%= if Map.get(@content, "tagline") do %>
          <p class="hero-tagline"><%= Map.get(@content, "tagline") %></p>
        <% end %>

        <%= if Map.get(@content, "description") do %>
          <p class="hero-description"><%= Map.get(@content, "description") %></p>
        <% end %>
      </div>

      <%= if Map.get(@content, "cta_text") && Map.get(@content, "cta_link") do %>
        <div class="cta-section">
          <a href={Map.get(@content, "cta_link")} class="cta-button">
            <%= Map.get(@content, "cta_text") %>
            <svg class="cta-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/>
            </svg>
          </a>
        </div>
      <% end %>

      <%= if Map.get(@content, "social_links") && map_size(Map.get(@content, "social_links")) > 0 do %>
        <div class="social-links">
          <p class="social-label">Connect with me</p>
          <div class="social-grid">
            <%= for {platform, url} <- Map.get(@content, "social_links") do %>
              <%= if url && url != "" do %>
                <a href={url} target="_blank" class="social-link">
                  <%= get_social_icon(platform) %>
                </a>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

      <style>
        .hero-content {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
        }

        .video-container {
          background: #1f2937;
          border-radius: 12px;
          overflow: hidden;
          aspect-ratio: 16/9;
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15);
        }

        .video-frame {
          width: 100%;
          height: 100%;
          object-fit: cover;
        }

        .text-content {
          display: flex;
          flex-direction: column;
          gap: 1rem;
        }

        .hero-headline {
          font-size: 2rem;
          font-weight: 800;
          color: #1f2937;
          line-height: 1.2;
          margin: 0;
        }

        .hero-tagline {
          font-size: 1.25rem;
          font-weight: 600;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          background-clip: text;
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          margin: 0;
        }

        .hero-description {
          color: #6b7280;
          line-height: 1.6;
          font-size: 1rem;
          margin: 0;
        }

        .cta-section {
          padding-top: 0.5rem;
        }

        .cta-button {
          display: inline-flex;
          align-items: center;
          gap: 0.5rem;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          color: white;
          padding: 0.875rem 1.5rem;
          border-radius: 12px;
          font-weight: 600;
          text-decoration: none;
          transition: all 0.3s ease;
          box-shadow: 0 4px 16px rgba(59, 130, 246, 0.3);
        }

        .cta-button:hover {
          transform: translateY(-2px);
          box-shadow: 0 8px 24px rgba(59, 130, 246, 0.4);
        }

        .cta-icon {
          width: 1rem;
          height: 1rem;
        }

        .social-links {
          padding-top: 1rem;
          border-top: 1px solid #e5e7eb;
        }

        .social-label {
          font-size: 0.875rem;
          color: #6b7280;
          margin: 0 0 0.75rem 0;
          font-weight: 500;
        }

        .social-grid {
          display: flex;
          gap: 0.75rem;
          flex-wrap: wrap;
        }

        .social-link {
          width: 2.5rem;
          height: 2.5rem;
          background: linear-gradient(135deg, #f3f4f6, #e5e7eb);
          border-radius: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: all 0.3s ease;
          text-decoration: none;
        }

        .social-link:hover {
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
        }

        .social-link:hover svg {
          color: white;
        }

        @media (max-width: 768px) {
          .hero-headline {
            font-size: 1.75rem;
          }

          .hero-tagline {
            font-size: 1.125rem;
          }

          .cta-button {
            padding: 0.75rem 1.25rem;
          }
        }
      </style>
    </div>
    """
  end

  # Introduction/About Section Renderer
  defp render_intro_content(content, _assigns) do
    assigns = %{content: content}

    ~H"""
    <div class="intro-content">
      <%= if Map.get(@content, "story") do %>
        <div class="story-section">
          <div class="story-text">
            <%= format_text_with_paragraphs(Map.get(@content, "story")) %>
          </div>
        </div>
      <% end %>

      <%= if Map.get(@content, "highlights") && length(Map.get(@content, "highlights")) > 0 do %>
        <div class="highlights-section">
          <h4 class="section-heading">Key Highlights</h4>
          <div class="highlights-list">
            <%= for highlight <- Map.get(@content, "highlights") do %>
              <div class="highlight-item">
                <div class="highlight-bullet"></div>
                <p class="highlight-text"><%= highlight %></p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if Map.get(@content, "personality_traits") && length(Map.get(@content, "personality_traits")) > 0 do %>
        <div class="traits-section">
          <h4 class="section-heading">Personality</h4>
          <div class="traits-grid">
            <%= for trait <- Map.get(@content, "personality_traits") do %>
              <span class="trait-tag"><%= trait %></span>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if Map.get(@content, "fun_facts") && length(Map.get(@content, "fun_facts")) > 0 do %>
        <div class="fun-facts-section">
          <h4 class="section-heading">Fun Facts</h4>
          <div class="facts-list">
            <%= for fact <- Map.get(@content, "fun_facts") do %>
              <div class="fact-item">
                <span class="fact-emoji">⭐</span>
                <p class="fact-text"><%= fact %></p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <style>
        .intro-content {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
        }

        .story-section {
          margin-bottom: 0.5rem;
        }

        .story-text {
          color: #374151;
          line-height: 1.7;
          font-size: 0.95rem;
        }

        .section-heading {
          font-weight: 600;
          color: #1f2937;
          margin: 0 0 0.75rem 0;
          font-size: 1rem;
        }

        .highlights-list {
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
        }

        .highlight-item {
          display: flex;
          align-items: flex-start;
          gap: 0.75rem;
        }

        .highlight-bullet {
          width: 0.5rem;
          height: 0.5rem;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          border-radius: 50%;
          margin-top: 0.5rem;
          flex-shrink: 0;
        }

        .highlight-text {
          color: #374151;
          margin: 0;
          font-size: 0.875rem;
          line-height: 1.5;
        }

        .traits-grid {
          display: flex;
          flex-wrap: wrap;
          gap: 0.5rem;
        }

        .trait-tag {
          background: linear-gradient(135deg, #f3e8ff, #ede9fe);
          color: #7c3aed;
          padding: 0.375rem 0.75rem;
          border-radius: 20px;
          font-size: 0.75rem;
          font-weight: 600;
          border: 1px solid rgba(124, 58, 237, 0.2);
        }

        .facts-list {
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
        }

        .fact-item {
          display: flex;
          align-items: flex-start;
          gap: 0.75rem;
        }

        .fact-emoji {
          font-size: 1rem;
          flex-shrink: 0;
        }

        .fact-text {
          color: #374151;
          margin: 0;
          font-size: 0.875rem;
          line-height: 1.5;
        }
      </style>
    </div>
    """
  end

  # Experience Section Renderer with clean design
  defp render_experience_content(content, _assigns) do
    # Handle both "items" and "jobs" for backward compatibility
    items = Map.get(content, "items", []) || Map.get(content, "jobs", [])
    assigns = %{items: items}

    ~H"""
    <div class="experience-content">
      <%= if length(@items) > 0 do %>
        <div class="experience-timeline">
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <div class="experience-item">
              <div class="experience-marker"></div>
              <div class="experience-card">
                <div class="experience-header">
                  <div class="experience-info">
                    <h4 class="experience-title">
                      <%= Map.get(item, "title", "Position") %>
                    </h4>
                    <p class="experience-company">
                      <%= Map.get(item, "company", "Company") %>
                    </p>
                  </div>
                  <%= if Map.get(item, "is_current") || Map.get(item, "current") do %>
                    <span class="current-badge">Current</span>
                  <% end %>
                </div>

                <div class="experience-meta">
                  <span class="experience-duration">
                    <%= Map.get(item, "start_date") %> - <%= Map.get(item, "end_date", "Present") %>
                  </span>
                  <%= if Map.get(item, "location") do %>
                    <span class="experience-location">• <%= Map.get(item, "location") %></span>
                  <% end %>
                </div>

                <%= if Map.get(item, "description") do %>
                  <p class="experience-description">
                    <%= Map.get(item, "description") %>
                  </p>
                <% end %>

                <%= if Map.get(item, "achievements") && length(Map.get(item, "achievements")) > 0 do %>
                  <div class="achievements-section">
                    <h5 class="achievements-title">Key Achievements</h5>
                    <ul class="achievements-list">
                      <%= for achievement <- Map.get(item, "achievements") do %>
                        <li class="achievement-item">
                          <span class="achievement-check">✓</span>
                          <%= achievement %>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <%= if Map.get(item, "skills_used") && length(Map.get(item, "skills_used")) > 0 do %>
                  <div class="skills-section">
                    <h5 class="skills-title">Skills Used</h5>
                    <div class="skills-grid">
                      <%= for skill <- Map.get(item, "skills_used") do %>
                        <span class="skill-tag"><%= skill %></span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="empty-state">
          <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0H8m8 0v6.879a2 2 0 01-.684 1.519l-2.996 2.683a2 2 0 01-1.336.519H6.016a2 2 0 01-1.336-.519l-2.996-2.683A2 2 0 011 10.879V4h15z"/>
          </svg>
          <p class="empty-message">No work experience added yet</p>
        </div>
      <% end %>

      <style>
        .experience-content {
          display: flex;
          flex-direction: column;
        }

        .experience-timeline {
          position: relative;
          padding-left: 1.5rem;
        }

        .experience-timeline::before {
          content: '';
          position: absolute;
          left: 0.5rem;
          top: 0;
          bottom: 0;
          width: 2px;
          background: linear-gradient(180deg, #3b82f6, #8b5cf6);
          border-radius: 1px;
        }

        .experience-item {
          position: relative;
          margin-bottom: 1.5rem;
        }

        .experience-item:last-child {
          margin-bottom: 0;
        }

        .experience-marker {
          position: absolute;
          left: -1.5rem;
          top: 0.5rem;
          width: 1rem;
          height: 1rem;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          border-radius: 50%;
          border: 3px solid white;
          box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
          z-index: 1;
        }

        .experience-card {
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border-radius: 12px;
          padding: 1.25rem;
          border: 1px solid rgba(226, 232, 240, 0.8);
        }

        .experience-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 0.75rem;
        }

        .experience-title {
          font-weight: 700;
          color: #1f2937;
          margin: 0;
          font-size: 1rem;
        }

        .experience-company {
          color: #3b82f6;
          font-weight: 600;
          margin: 0.25rem 0 0 0;
          font-size: 0.875rem;
        }

        .current-badge {
          background: linear-gradient(135deg, #10b981, #059669);
          color: white;
          padding: 0.25rem 0.75rem;
          border-radius: 12px;
          font-size: 0.75rem;
          font-weight: 600;
          box-shadow: 0 2px 4px rgba(16, 185, 129, 0.3);
        }

        .experience-meta {
          color: #6b7280;
          font-size: 0.8rem;
          margin-bottom: 0.75rem;
          font-weight: 500;
        }

        .experience-description {
          color: #374151;
          margin: 0 0 1rem 0;
          line-height: 1.5;
          font-size: 0.875rem;
        }

        .achievements-section,
        .skills-section {
          margin-top: 1rem;
        }

        .achievements-title,
        .skills-title {
          font-size: 0.75rem;
          font-weight: 600;
          color: #1f2937;
          margin: 0 0 0.5rem 0;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }

        .achievements-list {
          list-style: none;
          padding: 0;
          margin: 0;
          display: flex;
          flex-direction: column;
          gap: 0.375rem;
        }

        .achievement-item {
          display: flex;
          align-items: flex-start;
          gap: 0.5rem;
          font-size: 0.8rem;
          color: #374151;
          line-height: 1.4;
        }

        .achievement-check {
          color: #10b981;
          font-weight: 700;
          flex-shrink: 0;
          margin-top: 0.1rem;
        }

        .skills-grid {
          display: flex;
          flex-wrap: wrap;
          gap: 0.375rem;
        }

        .skill-tag {
          background: rgba(59, 130, 246, 0.1);
          color: #3b82f6;
          padding: 0.25rem 0.5rem;
          border-radius: 6px;
          font-size: 0.75rem;
          font-weight: 500;
          border: 1px solid rgba(59, 130, 246, 0.2);
        }

        @media (max-width: 768px) {
          .experience-timeline {
            padding-left: 1.25rem;
          }

          .experience-marker {
            left: -1.25rem;
            width: 0.75rem;
            height: 0.75rem;
          }

          .experience-card {
            padding: 1rem;
          }
        }
      </style>
    </div>
    """
  end

  # Helper functions (keeping existing logic but updating HTML structure)
  defp get_section_icon(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{icon: icon} -> icon
      _ -> "📄"
    end
  end

  defp get_section_color(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{category: "introduction"} -> "#3B82F6"
      %{category: "professional"} -> "#059669"
      %{category: "education"} -> "#7C3AED"
      %{category: "skills"} -> "#DC2626"
      %{category: "work"} -> "#EA580C"
      %{category: "creative"} -> "#DB2777"
      %{category: "business"} -> "#1F2937"
      %{category: "recognition"} -> "#F59E0B"
      %{category: "credentials"} -> "#6366F1"
      %{category: "social_proof"} -> "#10B981"
      %{category: "content"} -> "#8B5CF6"
      %{category: "network"} -> "#06B6D4"
      %{category: "contact"} -> "#EF4444"
      %{category: "narrative"} -> "#F97316"
      _ -> "#6B7280"
    end
  end

  defp darken_color(hex_color) do
    case hex_color do
      "#3B82F6" -> "#1D4ED8"
      "#059669" -> "#047857"
      "#7C3AED" -> "#5B21B6"
      "#DC2626" -> "#B91C1C"
      "#EA580C" -> "#C2410C"
      "#DB2777" -> "#BE185D"
      "#1F2937" -> "#111827"
      "#F59E0B" -> "#D97706"
      "#6366F1" -> "#4F46E5"
      "#10B981" -> "#059669"
      "#8B5CF6" -> "#7C3AED"
      "#06B6D4" -> "#0891B2"
      "#EF4444" -> "#DC2626"
      "#F97316" -> "#EA580C"
      _ -> "#4B5563"
    end
  end

  defp get_section_type_name(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{name: name} -> name
      _ -> String.capitalize(to_string(section_type))
    end
  end

  # Skills Section with enhanced design
  defp render_skills_content(content, _assigns) do
    display_style = Map.get(content, "display_style", "categorized")
    skills = Map.get(content, "skills", [])
    categories = Map.get(content, "categories", %{})

    assigns = %{
      display_style: display_style,
      skills: skills,
      categories: categories,
      show_proficiency: Map.get(content, "show_proficiency", true)
    }

    ~H"""
    <div class="skills-content">
      <%= case @display_style do %>
        <% "categorized" -> %>
          <div class="skills-categories">
            <%= for {category_name, category_skills} <- @categories do %>
              <%= if is_list(category_skills) && length(category_skills) > 0 do %>
                <div class="skill-category">
                  <h4 class="category-title"><%= category_name %></h4>
                  <div class="skills-grid">
                    <%= for skill <- category_skills do %>
                      <div class="skill-item">
                        <%= if is_map(skill) do %>
                          <div class="skill-content">
                            <span class="skill-name">
                              <%= Map.get(skill, "name", skill) %>
                            </span>
                            <%= if @show_proficiency && Map.get(skill, "proficiency") do %>
                              <span class="skill-level">
                                <%= Map.get(skill, "proficiency") %>
                              </span>
                              <div class="skill-progress">
                                <%= render_proficiency_bar(Map.get(skill, "proficiency")) %>
                              </div>
                            <% end %>
                          </div>
                        <% else %>
                          <span class="skill-name"><%= skill %></span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

        <% "flat_list" -> %>
          <div class="skills-flat-list">
            <div class="skills-tags">
              <%= for skill <- @skills do %>
                <span class="skill-tag">
                  <%= if is_map(skill), do: Map.get(skill, "name", skill), else: skill %>
                </span>
              <% end %>
            </div>
          </div>

        <% _ -> %>
          <div class="skills-default">
            <div class="skills-tags">
              <%= for skill <- @skills do %>
                <span class="skill-tag">
                  <%= if is_map(skill), do: Map.get(skill, "name", skill), else: skill %>
                </span>
              <% end %>
            </div>
          </div>
      <% end %>

      <style>
        .skills-content {
          display: flex;
          flex-direction: column;
        }

        .skills-categories {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
        }

        .skill-category {
          display: flex;
          flex-direction: column;
          gap: 0.75rem;
        }

        .category-title {
          font-weight: 600;
          color: #1f2937;
          margin: 0;
          font-size: 1rem;
          padding-bottom: 0.5rem;
          border-bottom: 2px solid #e5e7eb;
        }

        .skills-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 0.75rem;
        }

        .skill-item {
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border-radius: 10px;
          padding: 1rem;
          border: 1px solid rgba(226, 232, 240, 0.8);
          transition: all 0.3s ease;
        }

        .skill-item:hover {
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
          border-color: rgba(59, 130, 246, 0.3);
        }

        .skill-content {
          display: flex;
          flex-direction: column;
          gap: 0.5rem;
        }

        .skill-name {
          font-weight: 600;
          color: #1f2937;
          font-size: 0.875rem;
        }

        .skill-level {
          font-size: 0.75rem;
          color: #6b7280;
          font-weight: 500;
        }

        .skill-progress {
          width: 100%;
        }

        .skills-flat-list,
        .skills-default {
          display: flex;
          flex-direction: column;
        }

        .skills-tags {
          display: flex;
          flex-wrap: wrap;
          gap: 0.5rem;
        }

        .skill-tag {
          background: linear-gradient(135deg, #dbeafe, #bfdbfe);
          color: #1d4ed8;
          padding: 0.5rem 1rem;
          border-radius: 20px;
          font-size: 0.875rem;
          font-weight: 600;
          border: 1px solid rgba(29, 78, 216, 0.2);
          transition: all 0.3s ease;
        }

        .skill-tag:hover {
          background: linear-gradient(135deg, #3b82f6, #1d4ed8);
          color: white;
          transform: translateY(-2px);
          box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
        }

        @media (max-width: 768px) {
          .skills-grid {
            grid-template-columns: 1fr;
          }

          .skill-item {
            padding: 0.75rem;
          }
        }
      </style>
    </div>
    """
  end

  # Projects Section Renderer
  defp render_projects_content(content, _assigns) do
    items = Map.get(content, "items", [])
    assigns = %{items: items}

    ~H"""
    <div class="projects-content">
      <%= if length(@items) > 0 do %>
        <div class="projects-grid">
          <%= for item <- @items do %>
            <div class="project-card">
              <div class="project-header">
                <div class="project-info">
                  <h4 class="project-title">
                    <%= Map.get(item, "title", "Project Title") %>
                  </h4>
                  <%= if Map.get(item, "subtitle") do %>
                    <p class="project-subtitle">
                      <%= Map.get(item, "subtitle") %>
                    </p>
                  <% end %>
                </div>
                <%= if Map.get(item, "featured") do %>
                  <span class="featured-badge">Featured</span>
                <% end %>
              </div>

              <div class="project-meta">
                <%= if Map.get(item, "client") do %>
                  <span class="meta-item">Client: <%= Map.get(item, "client") %></span>
                <% end %>
                <%= if Map.get(item, "duration") do %>
                  <span class="meta-item">• <%= Map.get(item, "duration") %></span>
                <% end %>
                <%= if Map.get(item, "status") do %>
                  <span class="status-badge">
                    <%= Map.get(item, "status") %>
                  </span>
                <% end %>
              </div>

              <%= if Map.get(item, "description") do %>
                <p class="project-description">
                  <%= Map.get(item, "description") %>
                </p>
              <% end %>

              <%= if Map.get(item, "technologies") && length(Map.get(item, "technologies")) > 0 do %>
                <div class="technologies-section">
                  <h5 class="technologies-title">Technologies</h5>
                  <div class="technologies-grid">
                    <%= for tech <- Map.get(item, "technologies") do %>
                      <span class="tech-tag"><%= tech %></span>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <div class="project-links">
                <%= if Map.get(item, "live_url") do %>
                  <a href={Map.get(item, "live_url")} target="_blank" class="project-link live-link">
                    <svg class="link-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                    Live Demo
                  </a>
                <% end %>
                <%= if Map.get(item, "github_url") do %>
                  <a href={Map.get(item, "github_url")} target="_blank" class="project-link code-link">
                    <svg class="link-icon" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                    </svg>
                    Code
                  </a>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="empty-state">
          <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
          </svg>
          <p class="empty-message">No projects added yet</p>
        </div>
      <% end %>

      <style>
        .projects-content {
          display: flex;
          flex-direction: column;
        }

        .projects-grid {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
        }

        .project-card {
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border-radius: 12px;
          padding: 1.5rem;
          border: 1px solid rgba(226, 232, 240, 0.8);
          transition: all 0.3s ease;
        }

        .project-card:hover {
          transform: translateY(-4px);
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
          border-color: rgba(59, 130, 246, 0.3);
        }

        .project-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 0.75rem;
        }

        .project-title {
          font-weight: 700;
          color: #1f2937;
          margin: 0;
          font-size: 1.125rem;
        }

        .project-subtitle {
          color: #3b82f6;
          font-weight: 600;
          margin: 0.25rem 0 0 0;
          font-size: 0.875rem;
        }

        .featured-badge {
          background: linear-gradient(135deg, #f59e0b, #d97706);
          color: white;
          padding: 0.25rem 0.75rem;
          border-radius: 12px;
          font-size: 0.75rem;
          font-weight: 600;
          box-shadow: 0 2px 4px rgba(245, 158, 11, 0.3);
        }

        .project-meta {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          margin-bottom: 1rem;
          flex-wrap: wrap;
        }

        .meta-item {
          font-size: 0.8rem;
          color: #6b7280;
          font-weight: 500;
        }

        .status-badge {
          background: linear-gradient(135deg, #10b981, #059669);
          color: white;
          padding: 0.25rem 0.5rem;
          border-radius: 8px;
          font-size: 0.75rem;
          font-weight: 600;
        }

        .project-description {
          color: #374151;
          margin: 0 0 1rem 0;
          line-height: 1.6;
          font-size: 0.875rem;
        }

        .technologies-section {
          margin-bottom: 1rem;
        }

        .technologies-title {
          font-size: 0.75rem;
          font-weight: 600;
          color: #1f2937;
          margin: 0 0 0.5rem 0;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }

        .technologies-grid {
          display: flex;
          flex-wrap: wrap;
          gap: 0.375rem;
        }

        .tech-tag {
          background: rgba(59, 130, 246, 0.1);
          color: #3b82f6;
          padding: 0.25rem 0.5rem;
          border-radius: 6px;
          font-size: 0.75rem;
          font-weight: 600;
          border: 1px solid rgba(59, 130, 246, 0.2);
        }

        .project-links {
          display: flex;
          gap: 0.75rem;
          margin-top: 1rem;
        }

        .project-link {
          display: inline-flex;
          align-items: center;
          gap: 0.375rem;
          padding: 0.5rem 1rem;
          border-radius: 8px;
          font-size: 0.8rem;
          font-weight: 600;
          text-decoration: none;
          transition: all 0.3s ease;
        }

        .live-link {
          background: linear-gradient(135deg, #3b82f6, #1d4ed8);
          color: white;
          box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
        }

        .live-link:hover {
          transform: translateY(-2px);
          box-shadow: 0 4px 8px rgba(59, 130, 246, 0.4);
        }

        .code-link {
          background: linear-gradient(135deg, #374151, #1f2937);
          color: white;
          box-shadow: 0 2px 4px rgba(55, 65, 81, 0.3);
        }

        .code-link:hover {
          transform: translateY(-2px);
          box-shadow: 0 4px 8px rgba(55, 65, 81, 0.4);
        }

        .link-icon {
          width: 0.875rem;
          height: 0.875rem;
        }
      </style>
    </div>
    """
  end

  # Contact Section Renderer
  defp render_contact_content(content, _assigns) do
    assigns = %{content: content}

    ~H"""
    <div class="contact-content">
      <%= if Map.get(@content, "headline") do %>
        <h4 class="contact-headline">
          <%= Map.get(@content, "headline") %>
        </h4>
      <% end %>

      <%= if Map.get(@content, "description") do %>
        <p class="contact-description">
          <%= Map.get(@content, "description") %>
        </p>
      <% end %>

      <div class="contact-info">
        <%= if Map.get(@content, "email") do %>
          <div class="contact-item">
            <svg class="contact-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
            </svg>
            <a href={"mailto:#{Map.get(@content, "email")}"} class="contact-link">
              <%= Map.get(@content, "email") %>
            </a>
          </div>
        <% end %>

        <%= if Map.get(@content, "phone") do %>
          <div class="contact-item">
            <svg class="contact-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
            </svg>
            <a href={"tel:#{Map.get(@content, "phone")}"} class="contact-link">
              <%= Map.get(@content, "phone") %>
            </a>
          </div>
        <% end %>

        <%= if Map.get(@content, "location") do %>
          <div class="contact-item">
            <svg class="contact-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            <span class="contact-text">
              <%= Map.get(@content, "location") %>
            </span>
          </div>
        <% end %>

        <%= if Map.get(@content, "availability") do %>
          <div class="contact-item">
            <svg class="contact-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <span class="contact-text">
              <%= Map.get(@content, "availability") %>
            </span>
          </div>
        <% end %>
      </div>

      <%= if Map.get(@content, "social_links") && map_size(Map.get(@content, "social_links")) > 0 do %>
        <div class="social-section">
          <h5 class="social-heading">Connect</h5>
          <div class="social-grid">
            <%= for {platform, url} <- Map.get(@content, "social_links") do %>
              <%= if url && url != "" do %>
                <a href={url} target="_blank" class="social-item">
                  <%= get_social_icon(platform) %>
                  <span class="social-name">
                    <%= String.capitalize(platform) %>
                  </span>
                </a>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if Map.get(@content, "booking_link") do %>
        <div class="booking-section">
          <a href={Map.get(@content, "booking_link")} target="_blank" class="booking-button">
            Schedule a Meeting
          </a>
        </div>
      <% end %>

      <style>
        .contact-content {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
        }

        .contact-headline {
          font-weight: 700;
          color: #1f2937;
          margin: 0;
          font-size: 1.25rem;
        }

        .contact-description {
          color: #6b7280;
          margin: 0;
          line-height: 1.6;
          font-size: 0.875rem;
        }

        .contact-info {
          display: flex;
          flex-direction: column;
          gap: 1rem;
        }

        .contact-item {
          display: flex;
          align-items: center;
          gap: 0.75rem;
        }

        .contact-icon {
          width: 1.25rem;
          height: 1.25rem;
          color: #6b7280;
          flex-shrink: 0;
        }

        .contact-link {
          color: #3b82f6;
          text-decoration: none;
          font-weight: 500;
          font-size: 0.875rem;
          transition: color 0.3s ease;
        }

        .contact-link:hover {
          color: #1d4ed8;
        }

        .contact-text {
          color: #374151;
          font-size: 0.875rem;
          font-weight: 500;
        }

        .social-section {
          padding-top: 1rem;
          border-top: 1px solid #e5e7eb;
        }

        .social-heading {
          font-weight: 600;
          color: #1f2937;
          margin: 0 0 0.75rem 0;
          font-size: 1rem;
        }

        .social-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
          gap: 0.75rem;
        }

        .social-item {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          padding: 0.75rem;
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border-radius: 10px;
          text-decoration: none;
          transition: all 0.3s ease;
          border: 1px solid rgba(226, 232, 240, 0.8);
        }

        .social-item:hover {
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
          border-color: transparent;
        }

        .social-item:hover .social-name {
          color: white;
        }

        .social-item:hover svg {
          color: white;
        }

        .social-name {
          color: #374151;
          font-size: 0.8rem;
          font-weight: 600;
          transition: color 0.3s ease;
        }

        .booking-section {
          padding-top: 1rem;
          border-top: 1px solid #e5e7eb;
        }

        .booking-button {
          display: block;
          width: 100%;
          text-align: center;
          padding: 0.875rem 1.5rem;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          color: white;
          border-radius: 12px;
          font-weight: 600;
          text-decoration: none;
          transition: all 0.3s ease;
          box-shadow: 0 4px 16px rgba(59, 130, 246, 0.3);
        }

        .booking-button:hover {
          transform: translateY(-2px);
          box-shadow: 0 8px 24px rgba(59, 130, 246, 0.4);
        }
      </style>
    </div>
    """
  end

  # Default content renderer for unsupported section types
  defp render_default_content(content, _assigns) do
    assigns = %{content: content}

    ~H"""
    <div class="default-content">
      <%= if Map.get(@content, "content") do %>
        <div class="content-text">
          <p><%= Map.get(@content, "content") %></p>
        </div>
      <% else %>
        <div class="empty-state">
          <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          <p class="empty-message">No content added yet</p>
        </div>
      <% end %>

      <style>
        .default-content {
          display: flex;
          flex-direction: column;
        }

        .content-text {
          color: #374151;
          line-height: 1.6;
        }

        .content-text p {
          margin: 0;
          font-size: 0.875rem;
        }
      </style>
    </div>
    """
  end

  # Additional section renderers
  defp render_education_content(content, _assigns) do
    items = Map.get(content, "items", [])
    assigns = %{items: items}

    ~H"""
    <div class="education-content">
      <%= if length(@items) > 0 do %>
        <div class="education-timeline">
          <%= for item <- @items do %>
            <div class="education-item">
              <div class="education-marker"></div>
              <div class="education-card">
                <div class="education-header">
                  <div class="education-info">
                    <h4 class="education-degree">
                      <%= Map.get(item, "degree", "Degree") %>
                    </h4>
                    <p class="education-institution">
                      <%= Map.get(item, "institution", "Institution") %>
                    </p>
                  </div>
                  <%= if Map.get(item, "status") == "In Progress" do %>
                    <span class="progress-badge">In Progress</span>
                  <% end %>
                </div>

                <div class="education-meta">
                  <%= Map.get(item, "start_date") %> - <%= Map.get(item, "end_date", "Present") %>
                  <%= if Map.get(item, "location") do %>
                    • <%= Map.get(item, "location") %>
                  <% end %>
                </div>

                <%= if Map.get(item, "description") do %>
                  <p class="education-description">
                    <%= Map.get(item, "description") %>
                  </p>
                <% end %>

                <%= if Map.get(item, "relevant_coursework") && length(Map.get(item, "relevant_coursework")) > 0 do %>
                  <div class="coursework-section">
                    <h5 class="coursework-title">Relevant Coursework</h5>
                    <div class="coursework-grid">
                      <%= for course <- Map.get(item, "relevant_coursework") do %>
                        <span class="course-tag"><%= course %></span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="empty-state">
          <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M12 14l9-5-9-5-9 5 9 5z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
          </svg>
          <p class="empty-message">No education history added yet</p>
        </div>
      <% end %>

      <style>
        .education-content {
          display: flex;
          flex-direction: column;
        }

        .education-timeline {
          position: relative;
          padding-left: 1.5rem;
        }

        .education-timeline::before {
          content: '';
          position: absolute;
          left: 0.5rem;
          top: 0;
          bottom: 0;
          width: 2px;
          background: linear-gradient(180deg, #7c3aed, #a855f7);
          border-radius: 1px;
        }

        .education-item {
          position: relative;
          margin-bottom: 1.5rem;
        }

        .education-item:last-child {
          margin-bottom: 0;
        }

        .education-marker {
          position: absolute;
          left: -1.5rem;
          top: 0.5rem;
          width: 1rem;
          height: 1rem;
          background: linear-gradient(135deg, #7c3aed, #a855f7);
          border-radius: 50%;
          border: 3px solid white;
          box-shadow: 0 2px 8px rgba(124, 58, 237, 0.3);
          z-index: 1;
        }

        .education-card {
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border-radius: 12px;
          padding: 1.25rem;
          border: 1px solid rgba(226, 232, 240, 0.8);
        }

        .education-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 0.75rem;
        }

        .education-degree {
          font-weight: 700;
          color: #1f2937;
          margin: 0;
          font-size: 1rem;
        }

        .education-institution {
          color: #7c3aed;
          font-weight: 600;
          margin: 0.25rem 0 0 0;
          font-size: 0.875rem;
        }

        .progress-badge {
          background: linear-gradient(135deg, #3b82f6, #1d4ed8);
          color: white;
          padding: 0.25rem 0.75rem;
          border-radius: 12px;
          font-size: 0.75rem;
          font-weight: 600;
          box-shadow: 0 2px 4px rgba(59, 130, 246, 0.3);
        }

        .education-meta {
          color: #6b7280;
          font-size: 0.8rem;
          margin-bottom: 0.75rem;
          font-weight: 500;
        }

        .education-description {
          color: #374151;
          margin: 0 0 1rem 0;
          line-height: 1.5;
          font-size: 0.875rem;
        }

        .coursework-section {
          margin-top: 1rem;
        }

        .coursework-title {
          font-size: 0.75rem;
          font-weight: 600;
          color: #1f2937;
          margin: 0 0 0.5rem 0;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }

        .coursework-grid {
          display: flex;
          flex-wrap: wrap;
          gap: 0.375rem;
        }

        .course-tag {
          background: rgba(124, 58, 237, 0.1);
          color: #7c3aed;
          padding: 0.25rem 0.5rem;
          border-radius: 6px;
          font-size: 0.75rem;
          font-weight: 500;
          border: 1px solid rgba(124, 58, 237, 0.2);
        }
      </style>
    </div>
    """
  end

  defp render_testimonials_content(content, _assigns) do
    items = Map.get(content, "items", [])
    assigns = %{items: items}

    ~H"""
    <div class="testimonials-content">
      <%= if length(@items) > 0 do %>
        <div class="testimonials-grid">
          <%= for item <- @items do %>
            <div class="testimonial-card">
              <div class="testimonial-content">
                <blockquote class="testimonial-quote">
                  "<%= Map.get(item, "quote", "") %>"
                </blockquote>

                <div class="testimonial-author">
                  <%= if Map.get(item, "photo") do %>
                    <img src={Map.get(item, "photo")} alt={Map.get(item, "author", "Testimonial author")}
                         class="author-photo">
                  <% else %>
                    <div class="author-placeholder">
                      <svg class="placeholder-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                      </svg>
                    </div>
                  <% end %>

                  <div class="author-info">
                    <p class="author-name">
                      <%= Map.get(item, "author", "Anonymous") %>
                    </p>
                    <%= if Map.get(item, "title") || Map.get(item, "company") do %>
                      <p class="author-title">
                        <%= [Map.get(item, "title"), Map.get(item, "company")] |> Enum.filter(&(&1 && &1 != "")) |> Enum.join(" at ") %>
                      </p>
                    <% end %>

                    <%= if Map.get(item, "rating") do %>
                      <div class="rating-stars">
                        <%= for _i <- 1..String.to_integer(Map.get(item, "rating", "5")) do %>
                          <svg class="star-icon" viewBox="0 0 24 24">
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                          </svg>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="empty-state">
          <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"/>
          </svg>
          <p class="empty-message">No testimonials added yet</p>
        </div>
      <% end %>

      <style>
        .testimonials-content {
          display: flex;
          flex-direction: column;
        }

        .testimonials-grid {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
        }

        .testimonial-card {
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border-radius: 12px;
          padding: 1.5rem;
          border: 1px solid rgba(226, 232, 240, 0.8);
          transition: all 0.3s ease;
        }

        .testimonial-card:hover {
          transform: translateY(-4px);
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
          border-color: rgba(59, 130, 246, 0.3);
        }

        .testimonial-content {
          display: flex;
          flex-direction: column;
          gap: 1rem;
        }

        .testimonial-quote {
          color: #374151;
          margin: 0;
          font-style: italic;
          line-height: 1.6;
          font-size: 0.875rem;
          position: relative;
          padding-left: 1rem;
          border-left: 3px solid #3b82f6;
        }

        .testimonial-author {
          display: flex;
          align-items: center;
          gap: 0.75rem;
        }

        .author-photo {
          width: 2.5rem;
          height: 2.5rem;
          border-radius: 50%;
          object-fit: cover;
          border: 2px solid white;
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }

        .author-placeholder {
          width: 2.5rem;
          height: 2.5rem;
          background: linear-gradient(135deg, #e5e7eb, #d1d5db);
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          border: 2px solid white;
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }

        .placeholder-icon {
          width: 1.25rem;
          height: 1.25rem;
          color: #6b7280;
        }

        .author-info {
          flex: 1;
        }

        .author-name {
          font-weight: 600;
          color: #1f2937;
          margin: 0;
          font-size: 0.875rem;
        }

        .author-title {
          color: #6b7280;
          margin: 0.25rem 0 0 0;
          font-size: 0.75rem;
          font-weight: 500;
        }

        .rating-stars {
          display: flex;
          gap: 0.125rem;
          margin-top: 0.5rem;
        }

        .star-icon {
          width: 0.875rem;
          height: 0.875rem;
          fill: #f59e0b;
          color: #f59e0b;
        }
      </style>
    </div>
    """
  end

  defp render_services_content(content, _assigns) do
    items = Map.get(content, "items", [])
    assigns = %{items: items}

    ~H"""
    <div class="services-content">
      <%= if length(@items) > 0 do %>
        <div class="services-grid">
          <%= for item <- @items do %>
            <div class="service-card">
              <div class="service-header">
                <h4 class="service-name">
                  <%= Map.get(item, "name", "Service") %>
                </h4>
                <%= if Map.get(item, "featured") do %>
                  <span class="featured-badge">Featured</span>
                <% end %>
              </div>

              <%= if Map.get(item, "description") do %>
                <p class="service-description">
                  <%= Map.get(item, "description") %>
                </p>
              <% end %>

              <div class="service-details">
                <%= if Map.get(item, "duration") do %>
                  <div class="detail-item">
                    <span class="detail-label">Duration:</span>
                    <span class="detail-value"><%= Map.get(item, "duration") %></span>
                  </div>
                <% end %>

                <%= if Map.get(item, "price_range") do %>
                  <div class="detail-item">
                    <span class="detail-label">Price:</span>
                    <span class="detail-value"><%= Map.get(item, "price_range") %></span>
                  </div>
                <% end %>
              </div>

              <%= if Map.get(item, "includes") && length(Map.get(item, "includes")) > 0 do %>
                <div class="includes-section">
                  <h5 class="includes-title">Includes</h5>
                  <ul class="includes-list">
                    <%= for include <- Map.get(item, "includes") do %>
                      <li class="include-item">
                        <span class="include-check">✓</span>
                        <%= include %>
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% end %>

              <%= if Map.get(item, "booking_link") do %>
                <div class="service-action">
                  <a href={Map.get(item, "booking_link")} target="_blank" class="book-button">
                    Book Service
                    <svg class="book-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  </a>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="empty-state">
          <svg class="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0H8m8 0v6.879a2 2 0 01-.684 1.519l-2.996 2.683a2 2 0 01-1.336.519H6.016a2 2 0 01-1.336-.519l-2.996-2.683A2 2 0 011 10.879V4h15z"/>
          </svg>
          <p class="empty-message">No services added yet</p>
        </div>
      <% end %>

      <style>
        .services-content {
          display: flex;
          flex-direction: column;
        }

        .services-grid {
          display: flex;
          flex-direction: column;
          gap: 1.5rem;
        }

        .service-card {
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border-radius: 12px;
          padding: 1.5rem;
          border: 1px solid rgba(226, 232, 240, 0.8);
          transition: all 0.3s ease;
        }

        .service-card:hover {
          transform: translateY(-4px);
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
          border-color: rgba(59, 130, 246, 0.3);
        }

        .service-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 1rem;
        }

        .service-name {
          font-weight: 700;
          color: #1f2937;
          margin: 0;
          font-size: 1.125rem;
        }

        .featured-badge {
          background: linear-gradient(135deg, #f59e0b, #d97706);
          color: white;
          padding: 0.25rem 0.75rem;
          border-radius: 12px;
          font-size: 0.75rem;
          font-weight: 600;
          box-shadow: 0 2px 4px rgba(245, 158, 11, 0.3);
        }

        .service-description {
          color: #374151;
          margin: 0 0 1rem 0;
          line-height: 1.6;
          font-size: 0.875rem;
        }

        .service-details {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
          gap: 0.75rem;
          margin-bottom: 1rem;
        }

        .detail-item {
          display: flex;
          flex-direction: column;
          gap: 0.25rem;
        }

        .detail-label {
          font-weight: 600;
          color: #1f2937;
          font-size: 0.75rem;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }

        .detail-value {
          color: #6b7280;
          font-size: 0.875rem;
          font-weight: 500;
        }

        .includes-section {
          margin-bottom: 1rem;
        }

        .includes-title {
          font-size: 0.75rem;
          font-weight: 600;
          color: #1f2937;
          margin: 0 0 0.5rem 0;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }

        .includes-list {
          list-style: none;
          padding: 0;
          margin: 0;
          display: flex;
          flex-direction: column;
          gap: 0.375rem;
        }

        .include-item {
          display: flex;
          align-items: flex-start;
          gap: 0.5rem;
          font-size: 0.8rem;
          color: #374151;
          line-height: 1.4;
        }

        .include-check {
          color: #10b981;
          font-weight: 700;
          flex-shrink: 0;
          margin-top: 0.1rem;
        }

        .service-action {
          margin-top: 1rem;
          padding-top: 1rem;
          border-top: 1px solid #e5e7eb;
        }

        .book-button {
          display: inline-flex;
          align-items: center;
          gap: 0.5rem;
          background: linear-gradient(135deg, #3b82f6, #8b5cf6);
          color: white;
          padding: 0.75rem 1.25rem;
          border-radius: 10px;
          font-weight: 600;
          text-decoration: none;
          transition: all 0.3s ease;
          box-shadow: 0 4px 16px rgba(59, 130, 246, 0.3);
          font-size: 0.875rem;
        }

        .book-button:hover {
          transform: translateY(-2px);
          box-shadow: 0 6px 20px rgba(59, 130, 246, 0.4);
        }

        .book-icon {
          width: 1rem;
          height: 1rem;
        }
      </style>
    </div>
    """
  end

  # Helper functions
  defp render_proficiency_bar(proficiency) do
    percentage = case proficiency do
      "Beginner" -> 25
      "Intermediate" -> 50
      "Advanced" -> 75
      "Expert" -> 100
      _ -> 50
    end

    assigns = %{percentage: percentage}

    ~H"""
    <div class="proficiency-bar">
      <div class="proficiency-fill" style={"width: #{@percentage}%"}></div>
    </div>

    <style>
      .proficiency-bar {
        width: 100%;
        height: 0.25rem;
        background: #e5e7eb;
        border-radius: 2px;
        overflow: hidden;
      }

      .proficiency-fill {
        height: 100%;
        background: linear-gradient(90deg, #3b82f6, #8b5cf6);
        border-radius: 2px;
        transition: width 0.6s ease;
      }
    </style>
    """
  end

  defp get_social_icon(platform) do
    case String.downcase(platform) do
      "linkedin" ->
        Phoenix.HTML.raw("""
          <svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
            <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
          </svg>
        """)
      "github" ->
        Phoenix.HTML.raw("""
          <svg class="w-4 h-4 text-gray-800" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
          </svg>
        """)
      "twitter" ->
        Phoenix.HTML.raw("""
          <svg class="w-4 h-4 text-blue-400" fill="currentColor" viewBox="0 0 24 24">
            <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
          </svg>
        """)
      "instagram" ->
        Phoenix.HTML.raw("""
          <svg class="w-4 h-4 text-pink-500" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 6.62 5.367 11.987 11.988 11.987 6.62 0 11.987-5.367 11.987-11.987C24.014 5.367 18.637.001 12.017.001zM8.449 16.988c-1.297 0-2.448-.49-3.337-1.285C3.595 14.24 3.8 12.41 4.8 11.4c1.01-1.01 2.84-.795 4.313.678 1.474 1.473 1.688 3.303.678 4.313-.99 1-.99 1-2.342.597zM16.988 8.449c-1.297 0-2.448-.49-3.337-1.285-1.517-1.463-1.312-3.293-.312-4.303 1.01-1.01 2.84-.795 4.313.678 1.474 1.473 1.688 3.303.678 4.313-.99 1-.99 1-1.342.597z"/>
          </svg>
        """)
      _ ->
        Phoenix.HTML.raw("""
          <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
          </svg>
        """)
    end
  end

  # Video URL extraction helpers
  defp extract_youtube_id(url) when is_binary(url) do
    cond do
      String.contains?(url, "youtube.com/watch?v=") ->
        url |> String.split("v=") |> List.last() |> String.split("&") |> List.first()
      String.contains?(url, "youtu.be/") ->
        url |> String.split("youtu.be/") |> List.last() |> String.split("?") |> List.first()
      true -> url
    end
  end
  defp extract_youtube_id(_), do: ""

  defp extract_vimeo_id(url) when is_binary(url) do
    if String.contains?(url, "vimeo.com/") do
      url |> String.split("vimeo.com/") |> List.last() |> String.split("?") |> List.first()
    else
      url
    end
  end
  defp extract_vimeo_id(_), do: ""

  defp has_footer_content?(section) do
    section_type = to_string(section.section_type)
    case section_type do
      "contact" -> true
      "services" -> true
      _ -> false
    end
  end

  defp render_section_footer(section, assigns) do
    section_type = to_string(section.section_type)

    case section_type do
      "contact" ->
        assigns = Map.put(assigns, :section, section)
        ~H"""
        <div class="footer-text">
          💡 Ready to connect and collaborate
        </div>
        """
      _ ->
        assigns = Map.put(assigns, :section, section)
        ~H"""
        <div class="footer-text">
          Last updated: <%= format_date(@section.updated_at) %>
        </div>
        """
    end
  end

  defp format_date(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      _ -> "Recently"
    end
  end

  defp format_text_with_paragraphs(text) when is_binary(text) do
    Phoenix.HTML.raw("<p>#{text}</p>")
  end
  defp format_text_with_paragraphs(_), do: Phoenix.HTML.raw("")
end
