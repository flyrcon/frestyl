# lib/frestyl_web/live/portfolio_live/view.ex - UPDATED for custom URLs

defmodule FrestylWeb.PortfolioLive.View do
  use FrestylWeb, :live_view
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates

  # FIXED: Handle both public portfolio view and share token view
  def mount(%{"slug" => slug}, _session, socket) do
    # Check if this is a share token (longer, alphanumeric) or portfolio slug
    if String.length(slug) > 20 do
      # This looks like a share token
      mount_share_view(slug, socket)
    else
      # This is a portfolio slug
      mount_public_view(slug, socket)
    end
  end

  # Handle share token view (collaboration links)
  def mount(%{"token" => token}, _session, socket) do
    mount_share_view(token, socket)
  end

  # Mount public portfolio view
  defp mount_public_view(slug, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:error, :not_found} ->
        {:ok, socket
         |> put_flash(:error, "Portfolio not found")
         |> redirect(to: "/")}

      {:ok, portfolio} ->
        # Check if portfolio is publicly accessible
        if portfolio_accessible?(portfolio) do
          # Track visit
          track_portfolio_visit(portfolio, socket)

          # Get template configuration
          template_config = PortfolioTemplates.get_template_config(portfolio.theme || "executive")

          socket =
            socket
            |> assign(:page_title, portfolio.title)
            |> assign(:portfolio, portfolio)
            |> assign(:owner, portfolio.user)
            |> assign(:sections, Map.get(portfolio, :portfolio_sections, []))
            |> assign(:template_config, template_config)
            |> assign(:template_theme, normalize_theme(portfolio.theme))
            |> assign(:intro_video, get_intro_video(portfolio))
            |> assign(:share, nil)
            |> assign(:is_shared_view, false)
            |> assign(:show_stats, false) # Don't show stats in public view
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

  # Mount share token view (for collaboration)
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

        template_config = PortfolioTemplates.get_template_config(portfolio.theme || "executive")

        socket =
          socket
          |> assign(:page_title, "#{portfolio.title} - Shared")
          |> assign(:portfolio, portfolio)
          |> assign(:owner, portfolio.user)
          |> assign(:sections, portfolio.sections || [])
          |> assign(:template_config, template_config)
          |> assign(:template_theme, normalize_theme(portfolio.theme))
          |> assign(:intro_video, get_intro_video(portfolio))
          |> assign(:share, %{"name" => share.name || "shared user", "token" => token, "id" => share.id})
          |> assign(:is_shared_view, true)
          |> assign(:collaboration_enabled, collaboration_mode)
          |> assign(:feedback_panel_open, collaboration_mode)
          |> assign(:show_stats, false) # Don't show stats in shared views
          |> assign(:portfolio_stats, %{})

        {:ok, socket}
    end
  end

  # Check if portfolio is accessible to public
  defp portfolio_accessible?(portfolio) do
    case portfolio.visibility do
      :public -> true
      :link_only -> true  # Link-only portfolios are accessible via direct URL
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
  def handle_event("quick_highlight", %{"text" => highlighted_text, "section_id" => section_id}, socket) do
    if socket.assigns.collaboration_enabled do
      attrs = %{
        content: highlighted_text,
        feedback_type: :highlight,
        portfolio_id: socket.assigns.portfolio.id,
        section_id: section_id,
        share_id: get_share_id(socket),
        metadata: %{
          highlighted_text: highlighted_text,
          timestamp: DateTime.utc_now()
        }
      }

      case Portfolios.create_feedback(attrs) do
        {:ok, _feedback} ->
          {:noreply, put_flash(socket, :info, "Text highlighted and saved!")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to save highlight.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "min-h-screen",
      get_template_background(@template_theme)
    ]}>
      <!-- Portfolio Header -->
      <header class={[
        "relative overflow-hidden",
        get_header_background(@template_config)
      ]}>
        <!-- Background Pattern -->
        <div class="absolute inset-0 opacity-5">
          <div class="absolute inset-0" style="background-image: radial-gradient(circle at 1px 1px, white 1px, transparent 0); background-size: 20px 20px;"></div>
        </div>

        <div class="relative max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-16">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <!-- Profile Information -->
            <div class="space-y-6">
              <div class="flex items-center space-x-4">
                <div class="w-20 h-20 bg-white rounded-full shadow-lg flex items-center justify-center">
                  <span class="text-2xl font-bold text-gray-800">
                    <%= String.first(@owner.name || @owner.username || "U") %>
                  </span>
                </div>

                <div>
                  <h1 class="text-3xl lg:text-4xl font-bold text-white">
                    <%= @owner.name || @owner.username %>
                  </h1>

                  <%= if @owner.bio do %>
                    <p class="text-lg mt-1 text-white/90">
                      <%= @owner.bio %>
                    </p>
                  <% end %>
                </div>
              </div>

              <p class="text-lg leading-relaxed text-white/80">
                <%= @portfolio.description || "Welcome to my professional portfolio. Explore my work, experience, and achievements." %>
              </p>

              <!-- Share Attribution -->
              <%= if @is_shared_view and @share do %>
                <div class="bg-white/10 backdrop-blur-sm rounded-lg p-4 border border-white/20">
                  <p class="text-sm text-white/80">
                    <span class="font-medium">Shared by:</span> <%= @share["name"] %>
                  </p>
                </div>
              <% end %>
            </div>

            <!-- Intro Video or Visual -->
            <div class="lg:justify-self-end">
              <%= if @intro_video do %>
                <div class="relative rounded-2xl overflow-hidden shadow-2xl aspect-video bg-black">
                  <video controls class="w-full h-full object-cover">
                    <source src={get_media_url(@intro_video)} type="video/mp4" />
                  </video>

                  <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-4">
                    <p class="text-white text-sm font-medium">
                      👋 Personal Introduction
                    </p>
                  </div>
                </div>
              <% else %>
                <div class={[
                  "w-full aspect-square rounded-2xl shadow-2xl flex items-center justify-center",
                  get_placeholder_background(@template_config)
                ]}>
                  <div class="text-center">
                    <div class="w-24 h-24 mx-auto mb-4 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
                      <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                      </svg>
                    </div>
                    <h3 class="text-white text-lg font-semibold mb-2">Professional Portfolio</h3>
                    <p class="text-white/80 text-sm">Showcasing expertise and achievements</p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content Area -->
      <main class={[
        "py-8",
        get_template_spacing(@template_theme)
      ]}>
        <div class={get_template_layout_class(@template_theme)}>
          <!-- Portfolio Sections -->
          <%= for section <- @sections do %>
            <div class={[
              "bg-white rounded-xl shadow-lg border border-gray-200 hover:shadow-xl transition-shadow duration-300 p-6 mb-6",
              if(@collaboration_enabled, do: "hover:ring-2 hover:ring-blue-200", else: "")
            ]} id={"section-#{section.id}"}>
              <h2 class="text-2xl font-bold text-gray-900 mb-4"><%= section.title %></h2>

              <!-- Render section content based on type -->
              <%= render_section_content(section, assigns) %>

              <!-- Collaboration feedback button -->
              <%= if @collaboration_enabled do %>
                <div class="mt-4 pt-4 border-t border-gray-200">
                  <button phx-click="submit_feedback"
                          phx-value-section_id={section.id}
                          phx-value-feedback="Quick feedback on this section"
                          class="text-sm text-blue-600 hover:text-blue-800 font-medium">
                    💬 Add Feedback
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Empty State -->
          <%= if Enum.empty?(@sections) do %>
            <div class="text-center py-16">
              <div class="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
                <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">Portfolio Coming Soon</h3>
              <p class="text-gray-600 max-w-md mx-auto">
                <%= @owner.name || @owner.username %> is currently building their portfolio.
                Check back soon to see their professional journey!
              </p>
            </div>
          <% end %>
        </div>
      </main>

      <!-- Feedback Panel Toggle (for collaboration) -->
      <%= if @collaboration_enabled do %>
        <div class="fixed bottom-6 left-6 z-40">
          <button phx-click="toggle_feedback_panel"
                  class={[
                    "bg-blue-600 text-white shadow-lg rounded-full p-4 hover:bg-blue-700 transition-all duration-200",
                    @feedback_panel_open && "bg-blue-700"
                  ]}>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
            </svg>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Render section content based on section type
  defp render_section_content(%{section_type: :intro} = section, assigns) do
    headline = get_in(section.content, ["headline"]) || ""
    summary = get_in(section.content, ["summary"]) || ""
    location = get_in(section.content, ["location"]) || ""

    assigns = assign(assigns, headline: headline, summary: summary, location: location)

    ~H"""
    <%= if String.length(@headline) > 0 do %>
      <h3 class="text-xl font-semibold text-gray-800 mb-3"><%= @headline %></h3>
    <% end %>
    <%= if String.length(@summary) > 0 do %>
      <p class="text-gray-600 leading-relaxed mb-3"><%= @summary %></p>
    <% end %>
    <%= if String.length(@location) > 0 do %>
      <p class="text-sm text-gray-500 flex items-center">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
        </svg>
        <%= @location %>
      </p>
    <% end %>
    """
  end

  defp render_section_content(%{section_type: :contact} = section, assigns) do
    email = get_in(section.content, ["email"]) || ""
    phone = get_in(section.content, ["phone"]) || ""
    location = get_in(section.content, ["location"]) || ""

    assigns = assign(assigns, email: email, phone: phone, location: location)

    ~H"""
    <div class="space-y-3">
      <%= if String.length(@email) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
          </svg>
          <a href={"mailto:#{@email}"} class="text-blue-600 hover:text-blue-800"><%= @email %></a>
        </div>
      <% end %>

      <%= if String.length(@phone) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
          </svg>
          <a href={"tel:#{@phone}"} class="text-blue-600 hover:text-blue-800"><%= @phone %></a>
        </div>
      <% end %>

      <%= if String.length(@location) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <span class="text-gray-600"><%= @location %></span>
        </div>
      <% end %>
    </div>
    """
  end

  # Generic section content renderer
  defp render_section_content(section, _assigns) do
    content = case section.content do
      %{"summary" => summary} -> summary
      %{"description" => desc} -> desc
      %{"content" => content} -> content
      _ -> "Content coming soon..."
    end

    assigns = %{content: content, section_type: section.section_type}

    ~H"""
    <div class="prose max-w-none">
      <%= if String.length(@content) > 0 do %>
        <p class="text-gray-600 leading-relaxed"><%= @content %></p>
      <% else %>
        <p class="text-gray-400 italic">
          This <%= format_section_type(@section_type) %> section is being developed.
        </p>
      <% end %>
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
      _ -> :executive
    end
  end
  defp normalize_theme(theme) when is_atom(theme), do: theme
  defp normalize_theme(_), do: :executive

  defp get_template_background(template_theme) do
    case template_theme do
      :executive -> "bg-gradient-to-br from-slate-50 to-gray-100"
      :developer -> "bg-gradient-to-br from-indigo-50 via-white to-purple-50"
      :designer -> "bg-gradient-to-br from-pink-50 via-white to-rose-50"
      :consultant -> "bg-gradient-to-br from-blue-50 via-white to-cyan-50"
      :academic -> "bg-gradient-to-br from-emerald-50 via-white to-teal-50"
      _ -> "bg-white"
    end
  end

  defp get_template_spacing(template_theme) do
    case template_theme do
      :executive -> "space-y-8"
      :developer -> "space-y-6"
      :designer -> "space-y-12"
      :consultant -> "space-y-8"
      :academic -> "space-y-10"
      _ -> "space-y-8"
    end
  end

  defp get_template_layout_class(template_theme) do
    case template_theme do
      :executive -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
      :developer -> "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8"
      :designer -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
      :consultant -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
      :academic -> "max-w-4xl mx-auto px-4 sm:px-6 lg:px-8"
      _ -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
    end
  end

  defp get_header_background(template_config) do
    case template_config[:layout] do
      "dashboard" -> "bg-gradient-to-r from-slate-800 to-slate-900"
      "grid" -> "bg-gradient-to-r from-indigo-600 to-purple-600"
      "masonry" -> "bg-gradient-to-r from-pink-500 to-rose-500"
      "results_focused" -> "bg-gradient-to-r from-blue-600 to-cyan-600"
      "scholarly" -> "bg-gradient-to-r from-emerald-600 to-teal-600"
      _ -> "bg-gradient-to-r from-gray-800 to-gray-900"
    end
  end

  defp get_placeholder_background(template_config) do
    case template_config[:layout] do
      "dashboard" -> "bg-gradient-to-br from-slate-700 to-slate-800"
      "grid" -> "bg-gradient-to-br from-indigo-500 to-purple-600"
      "masonry" -> "bg-gradient-to-br from-pink-400 to-rose-500"
      "results_focused" -> "bg-gradient-to-br from-blue-500 to-cyan-600"
      "scholarly" -> "bg-gradient-to-br from-emerald-500 to-teal-600"
      _ -> "bg-gradient-to-br from-gray-700 to-gray-800"
    end
  end

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
    case Map.get(portfolio, :intro_video_id) do
      nil -> nil
      video_id -> Portfolios.get_media!(video_id)
    end
  rescue
    _ -> nil
  end

  defp get_share_id(socket) do
    case socket.assigns.share do
      %{"id" => id} -> id
      _ -> nil
    end
  end

  defp get_media_url(media) do
    Portfolios.get_media_url(media)
  end

  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media Showcase"
      :testimonial -> "Testimonials"
      :contact -> "Contact Information"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end
end
