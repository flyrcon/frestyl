# lib/frestyl_web/live/portfolio_live/components/public_block_renderer.ex
defmodule FrestylWeb.PortfolioLive.Components.PublicBlockRenderer do
  @moduledoc """
  Renders individual content blocks for public portfolio view.
  Supports all block types with layout-specific styling and interactions.
  """

  use FrestylWeb, :live_component

  @impl true
  def update(assigns, socket) do
    block_content = get_block_content_safe(assigns.block)
    media_items = get_block_media_safe(assigns.block)

    {:ok, socket
      |> assign(assigns)
      |> assign(:block_content, block_content)
      |> assign(:media_items, media_items)
      |> assign(:expanded, false)
    }
  end

  @impl true
  def handle_event("toggle_expansion", _params, socket) do
    {:noreply, assign(socket, :expanded, !socket.assigns.expanded)}
  end

  @impl true
  def handle_event("play_video", %{"video_id" => video_id}, socket) do
    {:noreply, push_event(socket, "play_video", %{video_id: video_id})}
  end

  @impl true
  def handle_event("open_lightbox", %{"media_id" => media_id}, socket) do
    {:noreply, send(self(), {:open_lightbox, media_id})}
  end

  @impl true
  def render(assigns) do
    block_type = get_block_type_safe(assigns.block)

    ~H"""
    <div class={[
      "public-block-renderer",
      "block-type-#{block_type}",
      "layout-#{@layout_type}",
      if(@expanded, do: "expanded", else: "collapsed")
    ]}
         id={"block-#{@block.id}"}
         data-block-type={block_type}>

      <%= case block_type do %>
        <% :hero_card -> %>
          <%= render_hero_block(assigns) %>
        <% :about_card -> %>
          <%= render_about_block(assigns) %>
        <% :experience_card -> %>
          <%= render_experience_block(assigns) %>
        <% :service_card -> %>
          <%= render_service_block(assigns) %>
        <% :project_card -> %>
          <%= render_project_block(assigns) %>
        <% :skill_card -> %>
          <%= render_skill_block(assigns) %>
        <% :testimonial_card -> %>
          <%= render_testimonial_block(assigns) %>
        <% :contact_card -> %>
          <%= render_contact_block(assigns) %>
        <% :media_showcase -> %>
          <%= render_media_showcase_block(assigns) %>
        <% _ -> %>
          <%= render_generic_block(assigns) %>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("send_contact_message", params, socket) do
    # Handle contact form submission
    # This could integrate with your contact system
    {:noreply, put_flash(socket, :info, "Message sent successfully!")}
  end

  # ============================================================================
  # HERO BLOCK RENDERER
  # ============================================================================

  defp render_hero_block(assigns) do
    ~H"""
    <div class={[
      "hero-block relative overflow-hidden",
      hero_layout_classes(@layout_type)
    ]}>
      <!-- Background Media -->
      <%= if has_background_media?(@media_items) do %>
        <%= render_hero_background_media(assigns) %>
      <% end %>

      <!-- Hero Content -->
      <div class="hero-content relative z-10">
        <div class={hero_content_container_classes(@layout_type)}>
          <!-- Title -->
          <%= if @block_content["title"] do %>
            <h1 class={hero_title_classes(@layout_type)}>
              <%= @block_content["title"] %>
            </h1>
          <% end %>

          <!-- Subtitle -->
          <%= if @block_content["subtitle"] do %>
            <p class={hero_subtitle_classes(@layout_type)}>
              <%= @block_content["subtitle"] %>
            </p>
          <% end %>

          <!-- Description -->
          <%= if @block_content["description"] do %>
            <div class={hero_description_classes(@layout_type)}>
              <%= render_formatted_text(@block_content["description"]) %>
            </div>
          <% end %>

          <!-- Call to Action Buttons -->
          <%= if @block_content["cta_buttons"] do %>
            <div class="hero-cta-buttons flex flex-wrap gap-4 mt-8">
              <%= for cta <- @block_content["cta_buttons"] do %>
                <a href={cta["url"] || "#"}
                   class={[
                     "inline-flex items-center px-6 py-3 rounded-lg font-semibold transition-all duration-200",
                     cta_button_classes(cta["style"] || "primary")
                   ]}
                   target={if cta["external"], do: "_blank", else: "_self"}>
                  <%= cta["text"] %>
                  <%= if cta["external"] do %>
                    <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  <% end %>
                </a>
              <% end %>
            </div>
          <% end %>

          <!-- Social Links -->
          <%= if @block_content["social_links"] do %>
            <div class="hero-social-links flex space-x-4 mt-6">
              <%= for social <- @block_content["social_links"] do %>
                <a href={social["url"]}
                   target="_blank"
                   class="w-10 h-10 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-white/30 transition-all duration-200">
                  <%= render_social_icon(social["platform"]) %>
                </a>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Video Play Button (if hero has video) -->
      <%= if has_hero_video?(@media_items) do %>
        <button class="absolute inset-0 z-20 flex items-center justify-center bg-black/30 opacity-0 hover:opacity-100 transition-opacity duration-300"
                phx-click="play_video"
                phx-value-video_id={get_hero_video_id(@media_items)}
                phx-target={@myself}>
          <div class="w-20 h-20 bg-white/90 rounded-full flex items-center justify-center">
            <svg class="w-8 h-8 text-gray-800 ml-1" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z"/>
            </svg>
          </div>
        </button>
      <% end %>
    </div>
    """
  end

  defp render_hero_background_media(assigns) do
    media = get_background_media(assigns.media_items)
    assigns = assign(assigns, :media, media)

    ~H"""
    <%= if @media.type == "video" do %>
      <video class="absolute inset-0 w-full h-full object-cover"
            autoplay
            muted
            loop
            playsinline>
        <source src={@media.url} type="video/mp4">
      </video>
      <div class="absolute inset-0 bg-black/40"></div>
    <% else %>
      <img src={@media.url}
          alt={@media.alt || "Hero background"}
          class="absolute inset-0 w-full h-full object-cover" />
      <div class="absolute inset-0 bg-black/30"></div>
    <% end %>
    """
  end

  # ============================================================================
  # ABOUT BLOCK RENDERER
  # ============================================================================

  defp render_about_block(assigns) do
    ~H"""
    <div class={[
      "about-block bg-white rounded-xl shadow-lg overflow-hidden",
      about_layout_classes(@layout_type)
    ]}>
      <div class="about-content p-6 lg:p-8">
        <!-- Profile Image & Basic Info -->
        <div class={about_header_layout(@layout_type)}>
          <%= if @block_content["profile_image"] do %>
            <div class="profile-image-container flex-shrink-0">
              <img src={@block_content["profile_image"]}
                   alt="Profile"
                   class={profile_image_classes(@layout_type)} />
            </div>
          <% end %>

          <div class="about-header-text">
            <%= if @block_content["title"] do %>
              <h2 class={about_title_classes(@layout_type)}>
                <%= @block_content["title"] %>
              </h2>
            <% end %>

            <%= if @block_content["subtitle"] do %>
              <p class="text-lg text-gray-600 mb-4">
                <%= @block_content["subtitle"] %>
              </p>
            <% end %>
          </div>
        </div>

        <!-- Main Content -->
        <%= if @block_content["content"] do %>
          <div class="about-main-content mt-6">
            <%= render_formatted_text(@block_content["content"]) %>
          </div>
        <% end %>

        <!-- Highlights/Key Points -->
        <%= if @block_content["highlights"] do %>
          <div class="about-highlights mt-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">Key Highlights</h3>
            <ul class="space-y-2">
              <%= for highlight <- @block_content["highlights"] do %>
                <li class="flex items-start space-x-3">
                  <div class="flex-shrink-0 w-5 h-5 bg-blue-100 rounded-full flex items-center justify-center mt-0.5">
                    <svg class="w-3 h-3 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                  </div>
                  <span class="text-gray-700"><%= highlight %></span>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <!-- Personal Stats/Metrics -->
        <%= if @block_content["stats"] do %>
          <div class="about-stats grid grid-cols-2 lg:grid-cols-4 gap-4 mt-8 pt-6 border-t border-gray-200">
            <%= for stat <- @block_content["stats"] do %>
              <div class="text-center">
                <div class="text-2xl font-bold text-blue-600"><%= stat["value"] %></div>
                <div class="text-sm text-gray-600"><%= stat["label"] %></div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # EXPERIENCE BLOCK RENDERER
  # ============================================================================

  defp render_experience_block(assigns) do
    ~H"""
    <div class={[
      "experience-block bg-white rounded-xl shadow-lg overflow-hidden",
      experience_layout_classes(@layout_type)
    ]}>
      <!-- Experience Header -->
      <div class="experience-header p-6 bg-gradient-to-r from-blue-50 to-purple-50 border-b border-gray-200">
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <%= if @block_content["job_title"] do %>
              <h3 class="text-xl font-bold text-gray-900 mb-1">
                <%= @block_content["job_title"] %>
              </h3>
            <% end %>

            <%= if @block_content["company"] do %>
              <div class="flex items-center space-x-2 text-lg text-gray-700 mb-2">
                <span><%= @block_content["company"] %></span>
                <%= if @block_content["company_url"] do %>
                  <a href={@block_content["company_url"]} target="_blank" class="text-blue-600 hover:text-blue-800">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  </a>
                <% end %>
              </div>
            <% end %>

            <%= if @block_content["duration"] do %>
              <div class="flex items-center space-x-2 text-sm text-gray-600">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <span><%= @block_content["duration"] %></span>
              </div>
            <% end %>
          </div>

          <!-- Company Logo -->
          <%= if @block_content["company_logo"] do %>
            <div class="flex-shrink-0 w-16 h-16 bg-white rounded-lg p-2 shadow-sm">
              <img src={@block_content["company_logo"]}
                   alt={"#{@block_content["company"]} logo"}
                   class="w-full h-full object-contain" />
            </div>
          <% end %>
        </div>
      </div>

      <!-- Experience Content -->
      <div class="experience-content p-6">
        <!-- Description -->
        <%= if @block_content["description"] do %>
          <div class="experience-description mb-6">
            <%= render_formatted_text(@block_content["description"]) %>
          </div>
        <% end %>

        <!-- Key Achievements -->
        <%= if @block_content["achievements"] do %>
          <div class="experience-achievements mb-6">
            <h4 class="text-lg font-semibold text-gray-900 mb-3">Key Achievements</h4>
            <ul class="space-y-3">
              <%= for achievement <- @block_content["achievements"] do %>
                <li class="flex items-start space-x-3">
                  <div class="flex-shrink-0 w-6 h-6 bg-green-100 rounded-full flex items-center justify-center mt-0.5">
                    <svg class="w-3 h-3 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                    </svg>
                  </div>
                  <span class="text-gray-700"><%= achievement %></span>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <!-- Technologies/Skills Used -->
        <%= if @block_content["technologies"] do %>
          <div class="experience-technologies">
            <h4 class="text-lg font-semibold text-gray-900 mb-3">Technologies & Skills</h4>
            <div class="flex flex-wrap gap-2">
              <%= for tech <- @block_content["technologies"] do %>
                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                  <%= tech %>
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Expandable Details -->
        <%= if @block_content["detailed_description"] && @layout_type != :minimal do %>
          <div class="experience-expansion mt-6">
            <button class="text-blue-600 hover:text-blue-800 font-medium text-sm flex items-center space-x-1"
                    phx-click="toggle_expansion"
                    phx-target={@myself}>
              <span><%= if @expanded, do: "Show Less", else: "Show More Details" %></span>
              <svg class={["w-4 h-4 transition-transform duration-200", if(@expanded, do: "rotate-180", else: "")]}
                   fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </button>

            <%= if @expanded do %>
              <div class="mt-4 p-4 bg-gray-50 rounded-lg">
                <%= render_formatted_text(@block_content["detailed_description"]) %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SERVICE BLOCK RENDERER
  # ============================================================================

  defp render_service_block(assigns) do
    ~H"""
    <div class={[
      "service-block bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow duration-300",
      service_layout_classes(@layout_type)
    ]}>
      <!-- Service Header -->
      <%= if @block_content["featured_image"] do %>
        <div class="service-image relative overflow-hidden">
          <img src={@block_content["featured_image"]}
               alt={@block_content["title"] || "Service"}
               class="w-full h-48 object-cover" />
          <div class="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent"></div>
        </div>
      <% end %>

      <div class="service-content p-6">
        <!-- Title & Pricing -->
        <div class="flex items-start justify-between mb-4">
          <div class="flex-1">
            <%= if @block_content["title"] do %>
              <h3 class="text-xl font-bold text-gray-900 mb-2">
                <%= @block_content["title"] %>
              </h3>
            <% end %>

            <%= if @block_content["description"] do %>
              <p class="text-gray-600 mb-4">
                <%= @block_content["description"] %>
              </p>
            <% end %>
          </div>

          <%= if @block_content["starting_price"] do %>
            <div class="flex-shrink-0 text-right">
              <div class="text-2xl font-bold text-green-600">
                <%= format_price(@block_content["starting_price"], @block_content["currency"]) %>
              </div>
              <%= if @block_content["pricing_model"] do %>
                <div class="text-sm text-gray-500">
                  <%= format_pricing_model(@block_content["pricing_model"]) %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Service Features -->
        <%= if @block_content["features"] do %>
          <div class="service-features mb-6">
            <ul class="space-y-2">
              <%= for feature <- @block_content["features"] do %>
                <li class="flex items-center space-x-3">
                  <svg class="w-5 h-5 text-green-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                  </svg>
                  <span class="text-gray-700"><%= feature %></span>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <!-- Service Metrics -->
        <%= if @block_content["duration"] || @block_content["deliverables"] do %>
          <div class="service-metrics grid grid-cols-2 gap-4 mb-6 p-4 bg-gray-50 rounded-lg">
            <%= if @block_content["duration"] do %>
              <div class="text-center">
                <div class="text-lg font-semibold text-gray-900"><%= @block_content["duration"] %></div>
                <div class="text-sm text-gray-600">Duration</div>
              </div>
            <% end %>

            <%= if @block_content["deliverables"] do %>
              <div class="text-center">
                <div class="text-lg font-semibold text-gray-900"><%= @block_content["deliverables"] %></div>
                <div class="text-sm text-gray-600">Deliverables</div>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Call to Action -->
        <%= if @block_content["booking_enabled"] do %>
          <div class="service-cta">
            <button class="w-full bg-blue-600 text-white font-semibold py-3 px-6 rounded-lg hover:bg-blue-700 transition-colors duration-200">
              <%= @block_content["cta_text"] || "Book This Service" %>
            </button>
          </div>
        <% else %>
          <div class="service-cta">
            <button class="w-full bg-gray-600 text-white font-semibold py-3 px-6 rounded-lg hover:bg-gray-700 transition-colors duration-200">
              Learn More
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # PROJECT BLOCK RENDERER
  # ============================================================================

  defp render_project_block(assigns) do
    ~H"""
    <div class={[
      "project-block bg-white rounded-xl shadow-lg overflow-hidden group hover:shadow-xl transition-all duration-300",
      project_layout_classes(@layout_type)
    ]}>
      <!-- Project Media -->
      <%= if has_project_media?(@media_items) do %>
        <div class="project-media relative overflow-hidden">
          <%= render_project_media_preview(assigns) %>

          <!-- Media Overlay -->
          <div class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-300 flex items-center justify-center">
            <button class="opacity-0 group-hover:opacity-100 w-12 h-12 bg-white/90 rounded-full flex items-center justify-center transition-opacity duration-300"
                    phx-click="open_lightbox"
                    phx-value-media_id={get_project_featured_media_id(@media_items)}
                    phx-target={@myself}>
              <svg class="w-6 h-6 text-gray-800" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            </button>
          </div>
        </div>
      <% end %>

      <div class="project-content p-6">
        <!-- Project Header -->
        <div class="project-header mb-4">
          <%= if @block_content["title"] do %>
            <h3 class="text-xl font-bold text-gray-900 mb-2">
              <%= @block_content["title"] %>
            </h3>
          <% end %>

          <%= if @block_content["subtitle"] do %>
            <p class="text-lg text-gray-600 mb-3">
              <%= @block_content["subtitle"] %>
            </p>
          <% end %>

          <%= if @block_content["description"] do %>
            <p class="text-gray-700 leading-relaxed">
              <%= @block_content["description"] %>
            </p>
          <% end %>
        </div>

        <!-- Project Technologies -->
        <%= if @block_content["technologies"] do %>
          <div class="project-technologies mb-6">
            <div class="flex flex-wrap gap-2">
              <%= for tech <- @block_content["technologies"] do %>
                <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                  <%= tech %>
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Project Stats -->
        <%= if has_project_stats?(@block_content) do %>
          <div class="project-stats grid grid-cols-3 gap-4 mb-6 p-4 bg-gray-50 rounded-lg">
            <%= if @block_content["completion_date"] do %>
              <div class="text-center">
                <div class="text-sm font-semibold text-gray-900"><%= format_date(@block_content["completion_date"]) %></div>
                <div class="text-xs text-gray-600">Completed</div>
              </div>
            <% end %>

            <%= if @block_content["team_size"] do %>
              <div class="text-center">
                <div class="text-sm font-semibold text-gray-900"><%= @block_content["team_size"] %></div>
                <div class="text-xs text-gray-600">Team Size</div>
              </div>
            <% end %>

            <%= if @block_content["duration"] do %>
              <div class="text-center">
                <div class="text-sm font-semibold text-gray-900"><%= @block_content["duration"] %></div>
                <div class="text-xs text-gray-600">Duration</div>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Project Links -->
        <%= if @block_content["links"] do %>
          <div class="project-links flex space-x-3">
            <%= for link <- @block_content["links"] do %>
              <a href={link["url"]}
                 target="_blank"
                 class={[
                   "inline-flex items-center px-4 py-2 rounded-lg font-medium text-sm transition-colors duration-200",
                   project_link_classes(link["type"])
                 ]}>
                <%= render_link_icon(link["type"]) %>
                <span class="ml-2"><%= link["label"] %></span>
              </a>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_project_media_preview(assigns) do
    ~H"""
    <%= if @media_items && length(@media_items) > 0 do %>
      <%= case List.first(@media_items) do %>
        <% %{type: "video"} = media -> %>
          <video class="w-full h-48 object-cover" preload="metadata" muted>
            <source src={media.url} type="video/mp4">
          </video>
        <% media -> %>
          <img src={media.url}
              alt={media.alt || "Project preview"}
              class="w-full h-48 object-cover" />
      <% end %>
    <% end %>
    """
  end

  # ============================================================================
  # SKILL BLOCK RENDERER
  # ============================================================================

  defp render_skill_block(assigns) do
    ~H"""
    <div class={[
      "skill-block bg-white rounded-xl shadow-lg overflow-hidden",
      skill_layout_classes(@layout_type)
    ]}>
      <div class="skill-content p-6">
        <%= if @block_content["title"] do %>
          <h3 class="text-xl font-bold text-gray-900 mb-6">
            <%= @block_content["title"] %>
          </h3>
        <% end %>

        <!-- Skills Grid/Cloud -->
        <%= if @block_content["skills"] do %>
          <div class="skills-container">
            <%= if @layout_type == :minimal do %>
              <!-- Minimal: Simple List -->
              <div class="skills-list space-y-3">
                <%= for skill <- @block_content["skills"] do %>
                  <div class="skill-item flex items-center justify-between">
                    <span class="font-medium text-gray-900"><%= skill["name"] %></span>
                    <div class="flex items-center space-x-2">
                      <div class="w-20 h-2 bg-gray-200 rounded-full">
                        <div class="h-full bg-blue-500 rounded-full" style={"width: #{skill["proficiency"] || 80}%"}></div>
                      </div>
                      <span class="text-sm text-gray-600"><%= skill["proficiency"] || 80 %>%</span>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <!-- Other layouts: Tag Cloud with Proficiency Colors -->
              <div class="skills-cloud flex flex-wrap gap-3">
                <%= for skill <- @block_content["skills"] do %>
                  <div class={[
                    "skill-tag inline-flex items-center px-4 py-2 rounded-full font-medium text-sm",
                    skill_proficiency_classes(skill["proficiency"] || 80)
                  ]}>
                    <span><%= skill["name"] %></span>
                    <%= if skill["years_experience"] do %>
                      <span class="ml-2 text-xs opacity-75">
                        <%= skill["years_experience"] %>y
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Skill Categories -->
        <%= if @block_content["categories"] do %>
          <div class="skill-categories mt-8 space-y-6">
            <%= for category <- @block_content["categories"] do %>
              <div class="skill-category">
                <h4 class="text-lg font-semibold text-gray-900 mb-3">
                  <%= category["name"] %>
                </h4>
                <div class="flex flex-wrap gap-2">
                  <%= for skill <- category["skills"] do %>
                    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800">
                      <%= skill %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # TESTIMONIAL BLOCK RENDERER
  # ============================================================================

  defp render_testimonial_block(assigns) do
    ~H"""
    <div class={[
      "testimonial-block bg-white rounded-xl shadow-lg overflow-hidden",
      testimonial_layout_classes(@layout_type)
    ]}>
      <div class="testimonial-content p-6">
        <!-- Quote -->
        <%= if @block_content["quote"] do %>
          <div class="testimonial-quote mb-6">
            <svg class="w-8 h-8 text-gray-300 mb-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.983zm-14.017 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h4v10h-10z"/>
            </svg>
            <blockquote class="text-lg text-gray-700 leading-relaxed italic">
              "<%= @block_content["quote"] %>"
            </blockquote>
          </div>
        <% end %>

        <!-- Client Info -->
        <div class="testimonial-client flex items-center space-x-4">
          <%= if @block_content["client_photo"] do %>
            <img src={@block_content["client_photo"]}
                 alt={@block_content["client_name"] || "Client"}
                 class="w-12 h-12 rounded-full object-cover" />
          <% else %>
            <div class="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center">
              <svg class="w-6 h-6 text-gray-400" fill="currentColor" viewBox="0 0 24 24">
                <path d="M24 20.993V24H0v-2.996A14.977 14.977 0 0112.004 15c4.904 0 9.26 2.354 11.996 5.993zM16.002 8.999a4 4 0 11-8 0 4 4 0 018 0z"/>
              </svg>
            </div>
          <% end %>

          <div class="flex-1">
            <%= if @block_content["client_name"] do %>
              <div class="font-semibold text-gray-900">
                <%= @block_content["client_name"] %>
              </div>
            <% end %>

            <%= if @block_content["client_title"] && @block_content["client_company"] do %>
              <div class="text-sm text-gray-600">
                <%= @block_content["client_title"] %> at <%= @block_content["client_company"] %>
              </div>
            <% end %>

            <!-- Rating -->
            <%= if @block_content["rating"] do %>
              <div class="flex items-center mt-1">
                <%= for i <- 1..5 do %>
                  <svg class={[
                    "w-4 h-4",
                    if(i <= (@block_content["rating"] || 5), do: "text-yellow-400", else: "text-gray-300")
                  ]} fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Project Context -->
        <%= if @block_content["project_context"] do %>
          <div class="testimonial-context mt-4 p-3 bg-gray-50 rounded-lg">
            <div class="text-sm text-gray-600">
              <strong>Project:</strong> <%= @block_content["project_context"] %>
            </div>
            <%= if @block_content["project_date"] do %>
              <div class="text-xs text-gray-500 mt-1">
                <%= @block_content["project_date"] %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # CONTACT BLOCK RENDERER
  # ============================================================================

  defp render_contact_block(assigns) do
    ~H"""
    <div class={[
      "contact-block bg-white rounded-xl shadow-lg overflow-hidden",
      contact_layout_classes(@layout_type)
    ]}>
      <div class="contact-content p-6">
        <%= if @block_content["title"] do %>
          <h3 class="text-xl font-bold text-gray-900 mb-6">
            <%= @block_content["title"] %>
          </h3>
        <% end %>

        <!-- Contact Methods -->
        <%= if @block_content["contact_methods"] do %>
          <div class="contact-methods space-y-4 mb-6">
            <%= for method <- @block_content["contact_methods"] do %>
              <div class="contact-method flex items-center space-x-3">
                <div class="flex-shrink-0 w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                  <%= render_contact_method_icon(method["type"]) %>
                </div>
                <div class="flex-1">
                  <div class="font-medium text-gray-900"><%= method["label"] %></div>
                  <%= if method["type"] == "email" do %>
                    <a href={"mailto:#{method["value"]}"} class="text-blue-600 hover:text-blue-800">
                      <%= method["value"] %>
                    </a>
                  <% else %>
                    <div class="text-gray-600"><%= method["value"] %></div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Quick Contact Form -->
        <%= if @block_content["show_contact_form"] do %>
          <div class="contact-form">
            <h4 class="text-lg font-semibold text-gray-900 mb-4">Send a Message</h4>
            <form phx-submit="send_contact_message" phx-target={@myself} class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <input type="text" name="name" placeholder="Your Name" required
                       class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" />
                <input type="email" name="email" placeholder="Your Email" required
                       class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" />
              </div>
              <input type="text" name="subject" placeholder="Subject" required
                     class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" />
              <textarea name="message" rows="4" placeholder="Your Message" required
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"></textarea>
              <button type="submit"
                      class="w-full bg-blue-600 text-white font-semibold py-3 px-6 rounded-lg hover:bg-blue-700 transition-colors duration-200">
                Send Message
              </button>
            </form>
          </div>
        <% end %>

        <!-- Social Links -->
        <%= if @block_content["social_links"] do %>
          <div class="contact-social mt-6 pt-6 border-t border-gray-200">
            <h4 class="text-lg font-semibold text-gray-900 mb-4">Connect With Me</h4>
            <div class="flex space-x-4">
              <%= for social <- @block_content["social_links"] do %>
                <a href={social["url"]}
                   target="_blank"
                   class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center text-gray-600 hover:bg-blue-100 hover:text-blue-600 transition-colors duration-200">
                  <%= render_social_icon(social["platform"]) %>
                </a>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MEDIA SHOWCASE BLOCK RENDERER
  # ============================================================================

  defp render_media_showcase_block(assigns) do
    ~H"""
    <div class={[
      "media-showcase-block bg-white rounded-xl shadow-lg overflow-hidden",
      media_showcase_layout_classes(@layout_type)
    ]}>
      <%= if @block_content["title"] do %>
        <div class="media-showcase-header p-6 border-b border-gray-200">
          <h3 class="text-xl font-bold text-gray-900">
            <%= @block_content["title"] %>
          </h3>
          <%= if @block_content["description"] do %>
            <p class="text-gray-600 mt-2">
              <%= @block_content["description"] %>
            </p>
          <% end %>
        </div>
      <% end %>

      <div class="media-showcase-content p-6">
        <%= if @media_items && is_list(@media_items) && length(@media_items) > 0 do %>
          <div class={media_gallery_classes(@layout_type)}>
            <%= for {media, index} <- Enum.with_index(@media_items) do %>
              <div class="media-item group cursor-pointer"
                   phx-click="open_lightbox"
                   phx-value-media_id={media.id}
                   phx-target={@myself}>
                <%= if media.type == "video" do %>
                  <div class="relative overflow-hidden rounded-lg">
                    <video class="w-full h-48 object-cover"
                           preload="metadata"
                           muted>
                      <source src={media.url} type="video/mp4">
                    </video>
                    <div class="absolute inset-0 bg-black/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                      <div class="w-12 h-12 bg-white/90 rounded-full flex items-center justify-center">
                        <svg class="w-6 h-6 text-gray-800 ml-1" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M8 5v14l11-7z"/>
                        </svg>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <div class="relative overflow-hidden rounded-lg">
                    <img src={media.url}
                         alt={media.alt || "Media item #{index + 1}"}
                         class="w-full h-48 object-cover group-hover:scale-105 transition-transform duration-300" />
                    <div class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-200"></div>
                  </div>
                <% end %>

                <%= if media.caption do %>
                  <div class="mt-2">
                    <p class="text-sm text-gray-600"><%= media.caption %></p>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-12 text-gray-500">
            <svg class="w-12 h-12 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
            <p>No media available</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # GENERIC BLOCK RENDERER (FALLBACK)
  # ============================================================================

  defp render_generic_block(assigns) do
    ~H"""
    <div class="generic-block bg-white rounded-xl shadow-lg overflow-hidden p-6">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-4">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="prose max-w-none">
          <%= render_formatted_text(@block_content["content"]) %>
        </div>
      <% end %>

      <!-- Display any media if present -->
      <%= if @media_items && is_list(@media_items) && length(@media_items) > 0 do %>
        <div class="generic-media mt-6 grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for media <- Enum.take(@media_items, 4) do %>
            <div class="media-item cursor-pointer"
                 phx-click="open_lightbox"
                 phx-value-media_id={media.id}
                 phx-target={@myself}>
              <%= if media.type == "video" do %>
                <video class="w-full h-32 object-cover rounded-lg" preload="metadata" muted>
                  <source src={media.url} type="video/mp4">
                </video>
              <% else %>
                <img src={media.url}
                     alt={media.alt || "Media"}
                     class="w-full h-32 object-cover rounded-lg" />
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # LAYOUT-SPECIFIC CSS CLASSES
  # ============================================================================

  defp hero_layout_classes(:minimal), do: "min-h-[40vh] bg-gradient-to-br from-gray-50 to-gray-100"
  defp hero_layout_classes(:list), do: "min-h-[50vh] bg-gradient-to-br from-blue-50 to-purple-50"
  defp hero_layout_classes(:gallery), do: "min-h-screen bg-gradient-to-br from-blue-600 to-purple-700 text-white"
  defp hero_layout_classes(:dashboard), do: "min-h-[60vh] bg-gradient-to-br from-blue-50 via-white to-purple-50"

  defp hero_content_container_classes(:minimal), do: "max-w-2xl mx-auto px-4 py-16 text-center"
  defp hero_content_container_classes(:list), do: "max-w-4xl mx-auto px-4 py-20 text-center"
  defp hero_content_container_classes(:gallery), do: "max-w-6xl mx-auto px-4 py-32 text-center"
  defp hero_content_container_classes(:dashboard), do: "max-w-7xl mx-auto px-4 py-24 text-center"

  defp hero_title_classes(:minimal), do: "text-3xl font-bold text-gray-900 mb-4"
  defp hero_title_classes(:list), do: "text-4xl font-bold text-gray-900 mb-6"
  defp hero_title_classes(:gallery), do: "text-6xl font-bold text-white mb-8 drop-shadow-lg"
  defp hero_title_classes(:dashboard), do: "text-5xl font-bold text-gray-900 mb-6"

  defp hero_subtitle_classes(:minimal), do: "text-lg text-gray-600 mb-6"
  defp hero_subtitle_classes(:list), do: "text-xl text-gray-600 mb-8"
  defp hero_subtitle_classes(:gallery), do: "text-2xl text-white/90 mb-10 drop-shadow"
  defp hero_subtitle_classes(:dashboard), do: "text-xl text-gray-600 mb-8"

  defp hero_description_classes(:minimal), do: "text-gray-700 mb-8"
  defp hero_description_classes(:list), do: "text-gray-700 mb-10 max-w-2xl mx-auto"
  defp hero_description_classes(:gallery), do: "text-white/80 mb-12 max-w-3xl mx-auto text-lg"
  defp hero_description_classes(:dashboard), do: "text-gray-700 mb-10 max-w-3xl mx-auto"

  defp about_layout_classes(:minimal), do: ""
  defp about_layout_classes(:list), do: "max-w-3xl"
  defp about_layout_classes(:gallery), do: "h-full"
  defp about_layout_classes(:dashboard), do: ""

  defp about_header_layout(:minimal), do: "flex flex-col items-center text-center space-y-4"
  defp about_header_layout(:list), do: "flex flex-col md:flex-row md:items-start md:space-x-6 space-y-4 md:space-y-0"
  defp about_header_layout(:gallery), do: "flex flex-col items-center text-center space-y-4"
  defp about_header_layout(:dashboard), do: "flex flex-col lg:flex-row lg:items-start lg:space-x-6 space-y-4 lg:space-y-0"

  defp profile_image_classes(:minimal), do: "w-24 h-24 rounded-full object-cover"
  defp profile_image_classes(:list), do: "w-32 h-32 rounded-xl object-cover"
  defp profile_image_classes(:gallery), do: "w-32 h-32 rounded-full object-cover"
  defp profile_image_classes(:dashboard), do: "w-40 h-40 rounded-xl object-cover"

  defp about_title_classes(:minimal), do: "text-2xl font-bold text-gray-900 mb-2"
  defp about_title_classes(:list), do: "text-3xl font-bold text-gray-900 mb-3"
  defp about_title_classes(:gallery), do: "text-2xl font-bold text-gray-900 mb-2"
  defp about_title_classes(:dashboard), do: "text-3xl font-bold text-gray-900 mb-3"

  defp experience_layout_classes(:minimal), do: "border-l-4 border-blue-500 pl-4"
  defp experience_layout_classes(:list), do: ""
  defp experience_layout_classes(:gallery), do: "h-full"
  defp experience_layout_classes(:dashboard), do: ""

  defp service_layout_classes(:minimal), do: "border border-gray-200"
  defp service_layout_classes(:list), do: ""
  defp service_layout_classes(:gallery), do: "h-full"
  defp service_layout_classes(:dashboard), do: ""

  defp project_layout_classes(:minimal), do: "border border-gray-200"
  defp project_layout_classes(:list), do: ""
  defp project_layout_classes(:gallery), do: "h-full"
  defp project_layout_classes(:dashboard), do: ""

  defp skill_layout_classes(:minimal), do: ""
  defp skill_layout_classes(:list), do: ""
  defp skill_layout_classes(:gallery), do: "h-full"
  defp skill_layout_classes(:dashboard), do: ""

  defp testimonial_layout_classes(:minimal), do: "border-l-4 border-green-500 pl-4"
  defp testimonial_layout_classes(:list), do: ""
  defp testimonial_layout_classes(:gallery), do: "h-full"
  defp testimonial_layout_classes(:dashboard), do: ""

  defp contact_layout_classes(:minimal), do: ""
  defp contact_layout_classes(:list), do: ""
  defp contact_layout_classes(:gallery), do: "h-full"
  defp contact_layout_classes(:dashboard), do: ""

  defp media_showcase_layout_classes(:minimal), do: ""
  defp media_showcase_layout_classes(:list), do: ""
  defp media_showcase_layout_classes(:gallery), do: "h-full"
  defp media_showcase_layout_classes(:dashboard), do: ""

  defp media_gallery_classes(:minimal), do: "grid grid-cols-2 gap-4"
  defp media_gallery_classes(:list), do: "grid grid-cols-1 md:grid-cols-2 gap-6"
  defp media_gallery_classes(:gallery), do: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
  defp media_gallery_classes(:dashboard), do: "grid grid-cols-2 lg:grid-cols-3 gap-4"

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp cta_button_classes("primary"), do: "bg-blue-600 text-white hover:bg-blue-700"
  defp cta_button_classes("secondary"), do: "bg-white text-blue-600 border-2 border-blue-600 hover:bg-blue-50"
  defp cta_button_classes("outline"), do: "bg-transparent text-white border-2 border-white hover:bg-white hover:text-blue-600"
  defp cta_button_classes(_), do: "bg-blue-600 text-white hover:bg-blue-700"

  defp skill_proficiency_classes(proficiency) when proficiency >= 90, do: "bg-green-100 text-green-800"
  defp skill_proficiency_classes(proficiency) when proficiency >= 70, do: "bg-blue-100 text-blue-800"
  defp skill_proficiency_classes(proficiency) when proficiency >= 50, do: "bg-yellow-100 text-yellow-800"
  defp skill_proficiency_classes(_), do: "bg-gray-100 text-gray-800"

  defp project_link_classes("live"), do: "bg-green-600 text-white hover:bg-green-700"
  defp project_link_classes("github"), do: "bg-gray-800 text-white hover:bg-gray-900"
  defp project_link_classes("demo"), do: "bg-blue-600 text-white hover:bg-blue-700"
  defp project_link_classes(_), do: "bg-gray-600 text-white hover:bg-gray-700"

  # ============================================================================
  # CONTENT EXTRACTION HELPERS
  # ============================================================================

  defp get_block_content_safe(block) do
    case block do
      %{content_data: content} when is_map(content) -> content
      %{"content_data" => content} when is_map(content) -> content
      %{content: content} when is_map(content) -> content
      %{"content" => content} when is_map(content) -> content
      _ -> %{}
    end
  end

  defp get_block_media_safe(_block) do
    # This would integrate with your existing media system
    # For now, return empty list
    []
  end

  defp get_block_type_safe(block) do
    case block do
      %{block_type: type} -> type
      %{"block_type" => type} when is_binary(type) -> String.to_atom(type)
      %{type: type} -> type
      %{"type" => type} when is_binary(type) -> String.to_atom(type)
      _ -> :text_card
    end
  end

  # ============================================================================
  # MEDIA HELPERS
  # ============================================================================

  defp has_background_media?(media_items) when is_list(media_items), do: length(media_items) > 0
  defp has_background_media?(_), do: false

  defp has_hero_video?(media_items) when is_list(media_items) do
    Enum.any?(media_items, fn item ->
      case item do
        %{type: "video"} -> true
        %{"type" => "video"} -> true
        _ -> false
      end
    end)
  end
  defp has_hero_video?(_), do: false

  defp has_project_media?(media_items) when is_list(media_items), do: length(media_items) > 0
  defp has_project_media?(_), do: false

  defp has_project_stats?(content) when is_map(content) do
    content["completion_date"] || content["team_size"] || content["duration"]
  end
  defp has_project_stats?(_), do: false

  defp get_background_media(media_items) when is_list(media_items) do
    case media_items do
      [first | _] -> first
      [] -> %{type: "image", url: "/images/default-hero-bg.jpg", alt: "Default background"}
    end
  end
  defp get_background_media(_), do: %{type: "image", url: "/images/default-hero-bg.jpg", alt: "Default background"}

  defp get_hero_video_id(media_items) when is_list(media_items) do
    case Enum.find(media_items, fn item ->
      case item do
        %{type: "video"} -> true
        %{"type" => "video"} -> true
        _ -> false
      end
    end) do
      %{id: id} -> id
      %{"id" => id} -> id
      _ -> nil
    end
  end
  defp get_hero_video_id(_), do: nil

  defp get_project_featured_media_id(media_items) when is_list(media_items) do
    case media_items do
      [first | _] ->
        case first do
          %{id: id} -> id
          %{"id" => id} -> id
          _ -> nil
        end
      [] -> nil
    end
  end
  defp get_project_featured_media_id(_), do: nil

  # Patch 6: Fix content extraction helpers to handle more data structures
  # Replace lines 699-712:

  defp get_block_content_safe(block) do
    case block do
      %{content_data: content} when is_map(content) -> content
      %{"content_data" => content} when is_map(content) -> content
      %{content: content} when is_map(content) -> content
      %{"content" => content} when is_map(content) -> content
      %{data: content} when is_map(content) -> content
      %{"data" => content} when is_map(content) -> content
      _ -> %{}
    end
  end

  defp get_block_media_safe(block) do
    case block do
      %{media_items: items} when is_list(items) -> items
      %{"media_items" => items} when is_list(items) -> items
      %{media: items} when is_list(items) -> items
      %{"media" => items} when is_list(items) -> items
      _ -> []
    end
  end

  defp get_block_type_safe(block) do
    case block do
      %{block_type: type} when is_atom(type) -> type
      %{block_type: type} when is_binary(type) -> String.to_atom(type)
      %{"block_type" => type} when is_binary(type) -> String.to_atom(type)
      %{type: type} when is_atom(type) -> type
      %{type: type} when is_binary(type) -> String.to_atom(type)
      %{"type" => type} when is_binary(type) -> String.to_atom(type)
      _ -> :text_card
    end
  end

  # ============================================================================
  # ICON RENDERERS
  # ============================================================================

  defp render_social_icon("linkedin") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
      <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
    </svg>
    """)
  end

  defp render_social_icon("twitter") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
      <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
    </svg>
    """)
  end

  defp render_social_icon("github") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
    </svg>
    """)
  end

  defp render_social_icon(_platform) do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
    </svg>
    """)
  end

  defp render_link_icon("live") do
    Phoenix.HTML.raw("""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
    </svg>
    """)
  end

defp render_link_icon("github"), do: render_social_icon("github")


  defp render_link_icon("demo") do
    Phoenix.HTML.raw("""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
    </svg>
    """)
  end

  defp render_link_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
    </svg>
    """)
  end

  defp render_contact_method_icon("email") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 7.89a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
    </svg>
    """)
  end

  defp render_contact_method_icon("phone") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
    </svg>
    """)
  end

  defp render_contact_method_icon("location") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
    </svg>
    """)
  end

  defp render_contact_method_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
    </svg>
    """)
  end

  # ============================================================================
  # FORMATTING HELPERS
  # ============================================================================

  defp render_formatted_text(text) when is_binary(text) do
    text
    |> String.replace("\n", "<br>")
    |> String.replace("\r\n", "<br>")
    |> String.replace("\r", "<br>")
    |> Phoenix.HTML.raw()
  end

  defp render_formatted_text(text) when is_list(text) do
    text
    |> Enum.join(" ")
    |> render_formatted_text()
  end

  defp render_formatted_text(_), do: ""

  defp format_price(price, currency) when is_binary(price) do
    case currency do
      "USD" -> "$#{price}"
      "EUR" -> "€#{price}"
      _ -> "#{currency || ""} #{price}"
    end
  end

  defp format_price(_, _), do: "Price on request"

  defp format_price(price, _currency), do: to_string(price)

  defp format_pricing_model("fixed"), do: "Fixed Price"
  defp format_pricing_model("hourly"), do: "Per Hour"
  defp format_pricing_model("project"), do: "Per Project"
  defp format_pricing_model(model), do: String.capitalize(to_string(model))

  defp format_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Calendar.strftime(date, "%B %Y")
      {:error, _} -> date_string
    end
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%B %Y")
  defp format_date(_), do: ""
end
