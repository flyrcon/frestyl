# lib/frestyl_web/live/portfolio_live/view.ex
# Cleaned and consolidated version with no duplicate functions

defmodule FrestylWeb.PortfolioLive.View do
  use FrestylWeb, :live_view
  alias Frestyl.Portfolios

  import Phoenix.HTML, only: [raw: 1]

  # MOUNT FUNCTIONS
  def mount(%{"slug" => slug}, _session, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}

      {:ok, portfolio} ->
        template_theme = normalize_theme(portfolio.theme)
        sections = Map.get(portfolio, :portfolio_sections, [])

        socket =
          socket
          |> assign(:portfolio, portfolio)
          |> assign(:owner, portfolio.user)
          |> assign(:sections, sections)
          |> assign(:template_theme, template_theme)
          |> assign(:intro_video, nil)
          |> assign(:share, nil)
          |> assign(:is_shared_view, false)
          |> assign(:feedback_stats, %{total: 0, pending: 0})
          |> assign(:exporting_resume, false)
          |> assign(:last_export, nil)

        {:ok, socket}
    end
  end

  def mount(%{"token" => token}, _session, socket) do
    case Portfolios.get_portfolio_by_share_token_simple(token) do
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}

      {:ok, portfolio, share} ->
        Portfolios.increment_share_view_count(token)

        socket =
          socket
          |> assign(:portfolio, portfolio)
          |> assign(:owner, portfolio.user)
          |> assign(:sections, portfolio.sections)
          |> assign(:template_theme, normalize_theme(portfolio.template_theme))
          |> assign(:intro_video, nil)
          |> assign(:share, %{"name" => share.name || "shared user", "token" => token})
          |> assign(:is_shared_view, true)
          |> assign(:feedback_stats, %{total: 0, pending: 0})
          |> assign(:exporting_resume, false)
          |> assign(:last_export, nil)

        {:ok, socket}
    end
  end

  # Fallback for testing
  def mount(params, session, socket) do
    portfolio = %{
      id: 1,
      title: "Test Portfolio",
      description: "A test portfolio for development",
      slug: "test-portfolio",
      template_theme: "creative",
      inserted_at: ~N[2024-01-01 00:00:00],
      updated_at: ~N[2024-12-01 00:00:00],
      allow_resume_export: true
    }

    owner = %{
      id: 1,
      name: "Test User",
      username: "testuser",
      full_name: "Test User"
    }

    sections = []

    socket =
      socket
      |> assign(:exporting_resume, false)
      |> assign(:last_export, nil)
      |> assign(:portfolio, portfolio)
      |> assign(:owner, owner)
      |> assign(:sections, sections)
      |> assign(:template_theme, :creative)
      |> assign(:intro_video, nil)
      |> assign(:share, nil)
      |> assign(:is_shared_view, false)
      |> assign(:feedback_stats, %{total: 0, pending: 0})

    {:ok, socket}
  end

  # EVENT HANDLERS
  @impl true
  def handle_event("submit_feedback", %{"feedback" => feedback_content, "section_id" => section_id}, socket) do
    if socket.assigns.is_shared_view do
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
      {:noreply, put_flash(socket, :error, "Feedback is only available for shared portfolios.")}
    end
  end

  @impl true
  def handle_event("export_resume", _params, socket) do
    case check_export_rate_limit(socket) do
      :ok ->
        pid = self()
        portfolio = socket.assigns.portfolio
        owner = socket.assigns.owner

        Task.start(fn ->
          case Frestyl.ResumeExporter.generate_pdf(portfolio, owner) do
            {:ok, pdf_binary} ->
              send(pid, {:pdf_ready, pdf_binary})
            {:error, reason} ->
              send(pid, {:pdf_error, reason})
          end
        end)

        {:noreply,
        socket
        |> assign(exporting_resume: true, last_export: DateTime.utc_now())
        |> put_flash(:info, "Generating your resume PDF...")}

      {:error, seconds_remaining} ->
        {:noreply,
        put_flash(socket, :error,
          "Please wait #{seconds_remaining} seconds before exporting again.")}
    end
  end

  @impl true
  def handle_info({ref, pdf_data}, socket) when is_reference(ref) do
    case socket.assigns do
      %{export_task: %{ref: ^ref}} ->
        Process.demonitor(ref, [:flush])

        {:noreply,
        socket
        |> assign(:export_task, nil)
        |> assign(:exporting_resume, false)
        |> put_flash(:info, "Resume PDF generated successfully!")
        |> push_event("download_pdf", %{
          data: Base.encode64(pdf_data),
          filename: "#{socket.assigns.portfolio.slug}_resume.pdf"
        })}

      _ ->
        {:noreply, socket}
    end
  end

  # HELPER FUNCTIONS
  defp normalize_theme(theme) when is_binary(theme) do
    case theme do
      "creative" -> :creative
      "corporate" -> :corporate
      "minimalist" -> :minimalist
      "default" -> :creative
      _ -> :creative
    end
  end
  defp normalize_theme(theme) when is_atom(theme), do: theme
  defp normalize_theme(_), do: :creative

  defp check_export_rate_limit(socket) do
    case socket.assigns[:last_export] do
      nil -> :ok
      last_time ->
        seconds_since = DateTime.diff(DateTime.utc_now(), last_time)
        if seconds_since >= 60 do
          :ok
        else
          {:error, 60 - seconds_since}
        end
    end
  end

  defp get_share_id(socket) do
    case socket.assigns.share do
      %{"token" => token} ->
        share = Portfolios.get_share_by_token(token)
        share && share.id
      _ -> nil
    end
  end

  # MEDIA HELPER FUNCTIONS
  def get_media_url(media) do
    Portfolios.get_media_url(media)
  end

  def get_video_thumbnail(video) do
    Portfolios.get_video_thumbnail(video)
  end

  # THEME AND LAYOUT FUNCTIONS
  def get_portfolio_layout_class(theme) do
    case theme do
      :creative -> "creative-layout"
      :corporate -> "corporate-layout"
      :minimalist -> "minimalist-layout"
      _ -> "creative-layout"
    end
  end

  def get_card_size_class(theme, section_type) do
    case {theme, section_type} do
      {:creative, :featured_project} -> "creative-featured-project featured-project"
      {:creative, :case_study} -> "creative-case-study case-study"
      {:creative, :media_showcase} -> "creative-media-showcase media-showcase"
      {:creative, :intro} -> "creative-intro"
      {:creative, :experience} -> "creative-experience"
      {:creative, _} -> "creative-standard"

      {:corporate, :featured_project} -> "featured-card featured-project"
      {:corporate, :case_study} -> "featured-card case-study"
      {:corporate, :media_showcase} -> "wide-card media-showcase"
      {:corporate, :experience} -> "wide-card"
      {:corporate, _} -> "standard-card"

      {:minimalist, :featured_project} -> "minimalist-standard featured-project"
      {:minimalist, :media_showcase} -> "minimalist-standard media-showcase"
      {:minimalist, :case_study} -> "minimalist-standard case-study"
      {:minimalist, _} -> "minimalist-standard"

      _ -> "portfolio-card-standard"
    end
  end

  def get_card_theme_class(theme) do
    case theme do
      :creative -> "bg-white/10 backdrop-blur-xl border border-white/20 shadow-2xl hover:shadow-white/10"
      :corporate -> "bg-white border border-gray-200 shadow-xl hover:shadow-2xl transition-shadow duration-300"
      :minimalist -> "bg-white border border-gray-100 shadow-lg hover:shadow-xl transition-shadow duration-300"
      _ -> "bg-white border border-gray-200 shadow-lg hover:shadow-xl"
    end
  end

  def get_gradient_class(section_type) do
    case section_type do
      :intro -> "bg-gradient-to-r from-blue-600 to-cyan-600 gradient-header-intro"
      :experience -> "bg-gradient-to-r from-green-600 to-teal-600 gradient-header-experience"
      :education -> "bg-gradient-to-r from-purple-600 to-indigo-600 gradient-header-education"
      :skills -> "bg-gradient-to-r from-orange-600 to-red-600 gradient-header-skills"
      :featured_project -> "bg-gradient-to-r from-pink-600 to-purple-600 gradient-header-featured"
      :case_study -> "bg-gradient-to-r from-indigo-600 to-purple-600 gradient-header-case-study"
      :media_showcase -> "bg-gradient-to-r from-cyan-600 to-blue-600 gradient-header-media"
      :contact -> "bg-gradient-to-r from-gray-600 to-gray-800 gradient-header-contact"
      _ -> "bg-gradient-to-r from-gray-600 to-gray-700 gradient-header-default"
    end
  end

  def get_icon_bg_class(theme, section_type) do
    case {theme, section_type} do
      {:creative, :featured_project} -> "bg-gradient-to-br from-yellow-400 to-pink-500 backdrop-blur-sm"
      {:creative, :experience} -> "bg-gradient-to-br from-blue-400 to-purple-500 backdrop-blur-sm"
      {:creative, :skills} -> "bg-gradient-to-br from-cyan-400 to-blue-500 backdrop-blur-sm"
      {:creative, :media_showcase} -> "bg-gradient-to-br from-purple-500 to-indigo-500 backdrop-blur-sm"
      {:creative, :case_study} -> "bg-gradient-to-br from-pink-500 to-purple-600 backdrop-blur-sm"
      {:creative, :intro} -> "bg-gradient-to-br from-blue-400 to-cyan-500 backdrop-blur-sm"
      {:creative, :education} -> "bg-gradient-to-br from-purple-400 to-indigo-500 backdrop-blur-sm"
      {:creative, _} -> "bg-white/20 backdrop-blur-sm"

      {:corporate, :featured_project} -> "bg-pink-100 border border-pink-200"
      {:corporate, :experience} -> "bg-green-100 border border-green-200"
      {:corporate, :skills} -> "bg-orange-100 border border-orange-200"
      {:corporate, :media_showcase} -> "bg-cyan-100 border border-cyan-200"
      {:corporate, :case_study} -> "bg-indigo-100 border border-indigo-200"
      {:corporate, :intro} -> "bg-blue-100 border border-blue-200"
      {:corporate, :education} -> "bg-purple-100 border border-purple-200"
      {:corporate, _} -> "bg-gray-100 border border-gray-200"

      {:minimalist, :featured_project} -> "bg-pink-50 border border-gray-200"
      {:minimalist, :experience} -> "bg-green-50 border border-gray-200"
      {:minimalist, :skills} -> "bg-orange-50 border border-gray-200"
      {:minimalist, :media_showcase} -> "bg-cyan-50 border border-gray-200"
      {:minimalist, :case_study} -> "bg-indigo-50 border border-gray-200"
      {:minimalist, :intro} -> "bg-blue-50 border border-gray-200"
      {:minimalist, :education} -> "bg-purple-50 border border-gray-200"
      {:minimalist, _} -> "bg-gray-50 border border-gray-200"

      _ -> "bg-gray-100"
    end
  end

  def get_title_class(theme) do
    case theme do
      :creative -> "text-white"
      :corporate -> "text-gray-900"
      :minimalist -> "text-gray-900"
      _ -> "text-gray-900"
    end
  end

  def get_badge_class(theme, section_type) do
    case {theme, section_type} do
      {:creative, _} -> "bg-white/20 text-white border-white/30"
      {:corporate, :intro} -> "bg-blue-100 text-blue-800 border-blue-200"
      {:corporate, :experience} -> "bg-green-100 text-green-800 border-green-200"
      {:corporate, :education} -> "bg-purple-100 text-purple-800 border-purple-200"
      {:corporate, :skills} -> "bg-orange-100 text-orange-800 border-orange-200"
      {:corporate, :featured_project} -> "bg-pink-100 text-pink-800 border-pink-200"
      {:corporate, :case_study} -> "bg-indigo-100 text-indigo-800 border-indigo-200"
      {:corporate, :media_showcase} -> "bg-cyan-100 text-cyan-800 border-cyan-200"
      {:corporate, _} -> "bg-gray-100 text-gray-800 border-gray-200"
      {:minimalist, _} -> "bg-gray-100 text-gray-700 border-gray-300"
      _ -> "bg-gray-100 text-gray-700 border-gray-300"
    end
  end

  def format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Experience"
      :education -> "Education"
      :skills -> "Skills"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media Showcase"
      :custom -> "Custom"
      _ -> String.capitalize(to_string(section_type))
    end
  end

  def get_section_description(section) do
    case section.section_type do
      :intro ->
        Map.get(section.content, "summary", "Introduction section")
      :experience ->
        jobs_count = length(Map.get(section.content, "jobs", []))
        "#{jobs_count} work experiences"
      :education ->
        edu_count = length(Map.get(section.content, "education", []))
        "#{edu_count} educational backgrounds"
      :skills ->
        skills_count = length(Map.get(section.content, "skills", []))
        "#{skills_count} skills listed"
      :featured_project ->
        Map.get(section.content, "description", "Featured project showcase")
      :case_study ->
        Map.get(section.content, "overview", "Detailed case study")
      :media_showcase ->
        Map.get(section.content, "description", "Media and visual content")
      :custom ->
        content = Map.get(section.content, "content", "Custom content section")
        if String.length(content) > 100, do: String.slice(content, 0, 100) <> "...", else: content
      _ ->
        "Portfolio section content"
    end
  end

  # ICON RENDERING FUNCTION
  def render_section_icon(section_type, theme) do
    icon_color = case theme do
      :creative -> "text-white"
      :corporate -> get_section_icon_color(section_type)
      :minimalist -> get_section_icon_color(section_type)
      _ -> get_section_icon_color(section_type)
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
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8zM16 10h.01"/>
        </svg>
        """)

      :skills ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """)

      :featured_project ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """)

      :education ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0v5m0-5h-.01M12 14l-9 5m9-5l9 5m0 0l-9 5-9-5m9-5l-9 5"/>
        </svg>
        """)

      :media_showcase ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>
        """)

      :case_study ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """)

      :custom ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """)
    end
  end

  defp get_section_icon_color(section_type) do
    case section_type do
      :intro -> "text-blue-600"
      :experience -> "text-green-600"
      :education -> "text-purple-600"
      :skills -> "text-orange-600"
      :featured_project -> "text-pink-600"
      :case_study -> "text-indigo-600"
      :media_showcase -> "text-cyan-600"
      :custom -> "text-slate-600"
      _ -> "text-gray-600"
    end
  end

  # CARD RENDERING FUNCTIONS
  def render_intro_card(assigns, section) do
    summary = Map.get(section.content, "summary", "")
    headline = Map.get(section.content, "headline", "")

    Phoenix.HTML.raw("""
    <div class="space-y-4">
      #{if headline != "", do: "<h4 class=\"text-lg font-bold text-gray-800\">#{headline}</h4>", else: ""}
      <p class="text-gray-600 leading-relaxed">#{summary}</p>
    </div>
    """)
  end

  def render_experience_card(assigns, section) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:jobs, Map.get(section.content || %{}, "jobs", []))
      |> assign(:has_jobs, length(Map.get(section.content || %{}, "jobs", [])) > 0)

    ~H"""
    <div class="space-y-4">
      <%= if @has_jobs do %>
        <%= for {job, index} <- Enum.with_index(Enum.take(@jobs, 3)) do %>
          <div class={[
            "p-4 rounded-xl border-l-4 transition-all duration-300 hover:shadow-lg",
            case @template_theme do
              :creative -> "bg-white/5 border-l-yellow-400"
              :corporate -> "bg-blue-50 border-l-blue-600"
              :minimalist -> "bg-gray-50 border-l-gray-900"
            end
          ]}>
            <div class="flex justify-between items-start mb-3">
              <div>
                <h4 class={[
                  "font-bold text-lg",
                  case @template_theme do
                    :creative -> "text-white"
                    :corporate -> "text-gray-900"
                    :minimalist -> "text-gray-900"
                  end
                ]}>
                  <%= Map.get(job, "title") %>
                </h4>
                <p class={[
                  "font-medium",
                  case @template_theme do
                    :creative -> "text-white/80"
                    :corporate -> "text-blue-600"
                    :minimalist -> "text-gray-600"
                  end
                ]}>
                  <%= Map.get(job, "company") %>
                </p>
              </div>
              <%= if Map.get(job, "current") do %>
                <span class="inline-flex items-center px-2 py-1 bg-green-100 text-green-600 text-xs font-bold rounded-full">
                  <div class="w-2 h-2 bg-green-400 rounded-full mr-1 animate-pulse"></div>
                  Current
                </span>
              <% end %>
            </div>

            <div class={[
              "text-sm font-medium mb-2",
              case @template_theme do
                :creative -> "text-white/70"
                :corporate -> "text-gray-500"
                :minimalist -> "text-gray-500"
              end
            ]}>
              <%= Map.get(job, "start_date") %> -
              <%= if Map.get(job, "current"), do: "Present", else: Map.get(job, "end_date") %>
            </div>

            <%= if Map.get(job, "description") do %>
              <p class={[
                "text-sm leading-relaxed",
                case @template_theme do
                  :creative -> "text-white/90"
                  :corporate -> "text-gray-700"
                  :minimalist -> "text-gray-600"
                end
              ]}>
                <%= String.slice(Map.get(job, "description"), 0, 120) %>
                <%= if String.length(Map.get(job, "description")) > 120, do: "..." %>
              </p>
            <% end %>
          </div>
        <% end %>

        <%= if length(@jobs) > 3 do %>
          <div class="text-center">
            <button class={[
              "text-sm font-semibold px-4 py-2 rounded-lg transition-colors",
              case @template_theme do
                :creative -> "text-white/80 hover:text-white"
                :corporate -> "text-blue-600 hover:text-blue-700"
                :minimalist -> "text-gray-600 hover:text-gray-700"
              end
            ]}>
              View <%= length(@jobs) - 3 %> more positions →
            </button>
          </div>
        <% end %>
      <% else %>
        <div class="text-center py-8">
          <svg class="w-12 h-12 mx-auto mb-4 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
          </svg>
          <p class={[
            "text-sm",
            case @template_theme do
              :creative -> "text-white/70"
              :corporate -> "text-gray-500"
              :minimalist -> "text-gray-500"
            end
          ]}>
            Professional experience details coming soon
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  def render_skills_card(assigns, section) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:skills, Map.get(section.content || %{}, "skills", []))
      |> assign(:has_skills, length(Map.get(section.content || %{}, "skills", [])) > 0)

    ~H"""
    <div class="space-y-4">
      <%= if @has_skills do %>
        <div>
          <div class="flex flex-wrap gap-2">
            <%= for skill <- Enum.take(@skills, 12) do %>
              <span class={[
                "px-3 py-2 text-sm font-semibold rounded-xl transition-all duration-300 hover:scale-105",
                case @template_theme do
                  :creative -> "bg-gradient-to-r from-cyan-500/20 to-blue-500/20 text-white border border-white/20"
                  :corporate -> "bg-blue-100 text-blue-800 hover:bg-blue-200"
                  :minimalist -> "bg-gray-100 text-gray-700 hover:bg-gray-200"
                end
              ]}>
                <%= skill %>
              </span>
            <% end %>
          </div>

          <%= if length(@skills) > 12 do %>
            <div class="mt-4 text-center">
              <button class={[
                "text-sm font-semibold px-4 py-2 rounded-lg transition-colors",
                case @template_theme do
                  :creative -> "text-white/80 hover:text-white"
                  :corporate -> "text-blue-600 hover:text-blue-700"
                  :minimalist -> "text-gray-600 hover:text-gray-700"
                end
              ]}>
                Show <%= length(@skills) - 12 %> more skills →
              </button>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-8">
          <svg class="w-12 h-12 mx-auto mb-4 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
          <p class={[
            "text-sm",
            case @template_theme do
              :creative -> "text-white/70"
              :corporate -> "text-gray-500"
              :minimalist -> "text-gray-500"
            end
          ]}>
            Skills and competencies will be showcased here
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  def render_education_card(assigns, section) do
    education = Map.get(section.content, "education", [])

    Phoenix.HTML.raw("""
    <div class="space-y-4">
      #{Enum.map(Enum.take(education, 2), fn edu ->
        "<div class=\"border-l-4 border-purple-500 pl-4\">
          <h4 class=\"font-bold text-gray-900\">#{Map.get(edu, "degree", "")} #{Map.get(edu, "field", "")}</h4>
          <p class=\"text-purple-600 font-medium\">#{Map.get(edu, "institution", "")}</p>
          <p class=\"text-sm text-gray-500\">#{Map.get(edu, "start_date", "")} - #{Map.get(edu, "end_date", "")}</p>
        </div>"
      end) |> Enum.join("")}
    </div>
    """)
  end

  def render_featured_project_card(assigns, section) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:description, Map.get(section.content || %{}, "description"))
      |> assign(:media_files, Map.get(section, :media_files, []))
      |> assign(:has_media, length(Map.get(section, :media_files, [])) > 0)
      |> assign(:technologies, Map.get(section.content || %{}, "technologies", []))
      |> assign(:has_technologies, length(Map.get(section.content || %{}, "technologies", [])) > 0)
      |> assign(:demo_url, Map.get(section.content || %{}, "demo_url"))
      |> assign(:github_url, Map.get(section.content || %{}, "github_url"))
      |> assign(:has_links, Map.get(section.content || %{}, "demo_url") || Map.get(section.content || %{}, "github_url"))

    ~H"""
    <div class="space-y-6">
      <%= if @description do %>
        <p class={[
          "text-lg leading-relaxed",
          case @template_theme do
            :creative -> "text-white/90"
            :corporate -> "text-gray-700"
            :minimalist -> "text-gray-600"
          end
        ]}>
          <%= @description %>
        </p>
      <% end %>

      <%= if @has_media do %>
        <div class="grid grid-cols-2 gap-4">
          <%= for {media, index} <- Enum.with_index(Enum.take(@media_files, 4)) do %>
            <div class="relative group overflow-hidden rounded-xl aspect-video">
              <%= case Map.get(media, :media_type) do %>
                <% :image -> %>
                  <img src={get_media_url(media)}
                      alt={Map.get(media, :title) || "Project media"}
                      class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110" />
                <% :video -> %>
                  <video class="w-full h-full object-cover"
                        poster={get_video_thumbnail(media)}
                        preload="metadata">
                    <source src={get_media_url(media)} type="video/mp4" />
                  </video>
                  <div class="absolute inset-0 flex items-center justify-center">
                    <div class="w-12 h-12 bg-black/60 rounded-full flex items-center justify-center backdrop-blur-sm">
                      <svg class="w-6 h-6 text-white ml-1" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                      </svg>
                    </div>
                  </div>
                <% _ -> %>
                  <div class="w-full h-full bg-gray-200 flex items-center justify-center">
                    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                  </div>
              <% end %>

              <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-3 opacity-0 group-hover:opacity-100 transition-opacity">
                <p class="text-white text-sm font-medium">
                  <%= Map.get(media, :title) || "Project Asset #{index + 1}" %>
                </p>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @has_technologies do %>
        <div class="flex flex-wrap gap-2">
          <%= for tech <- Enum.take(@technologies, 6) do %>
            <span class={[
              "px-3 py-1 text-xs font-bold rounded-full",
              case @template_theme do
                :creative -> "bg-gradient-to-r from-purple-500/20 to-pink-500/20 text-white border border-white/20"
                :corporate -> "bg-blue-100 text-blue-800"
                :minimalist -> "bg-gray-100 text-gray-700"
              end
            ]}>
              <%= tech %>
            </span>
          <% end %>
        </div>
      <% end %>

      <%= if @has_links do %>
        <div class="flex gap-3">
          <%= if @demo_url do %>
            <a href={@demo_url} target="_blank"
              class={[
                "inline-flex items-center px-4 py-2 text-sm font-semibold rounded-lg transition-all duration-300 hover:scale-105",
                case @template_theme do
                  :creative -> "bg-gradient-to-r from-yellow-400 to-pink-500 text-black shadow-lg"
                  :corporate -> "bg-blue-600 text-white hover:bg-blue-700"
                  :minimalist -> "bg-gray-900 text-white hover:bg-gray-800"
                end
              ]}>
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
              </svg>
              Live Demo
            </a>
          <% end %>

          <%= if @github_url do %>
            <a href={@github_url} target="_blank"
              class={[
                "inline-flex items-center px-4 py-2 text-sm font-semibold rounded-lg border transition-all duration-300 hover:scale-105",
                case @template_theme do
                  :creative -> "bg-white/10 text-white border-white/30 hover:bg-white/20"
                  :corporate -> "bg-gray-100 text-gray-700 border-gray-300 hover:bg-gray-200"
                  :minimalist -> "bg-gray-100 text-gray-700 border-gray-300 hover:bg-gray-200"
                end
              ]}>
              <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
              </svg>
              View Code
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def render_media_showcase_card(assigns, section) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:media_files, Map.get(section, :media_files, []))
      |> assign(:has_media, length(Map.get(section, :media_files, [])) > 0)
      |> assign(:context, Map.get(section.content || %{}, "context"))

    ~H"""
    <div class="space-y-4">
      <%= if @has_media do %>
        <div class="grid grid-cols-1 gap-4">
          <%= for {media, index} <- Enum.with_index(Enum.take(@media_files, 3)) do %>
            <div class="relative group overflow-hidden rounded-xl aspect-video bg-black">
              <%= case Map.get(media, :media_type) do %>
                <% :image -> %>
                  <img src={get_media_url(media)}
                      alt={Map.get(media, :title) || "Showcase media"}
                      class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110" />
                <% :video -> %>
                  <video class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                        poster={get_video_thumbnail(media)}
                        preload="metadata"
                        controls>
                    <source src={get_media_url(media)} type="video/mp4" />
                  </video>
              <% end %>

              <div class="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-all duration-500">
                <div class="absolute bottom-0 left-0 right-0 p-6 text-white">
                  <h5 class="font-bold text-lg mb-2">
                    <%= Map.get(media, :title) || "Featured Work" %>
                  </h5>

                  <%= if Map.get(media, :description) do %>
                    <p class="text-white/90 mb-4 leading-relaxed text-sm">
                      <%= String.slice(Map.get(media, :description), 0, 100) %>
                      <%= if String.length(Map.get(media, :description)) > 100, do: "..." %>
                    </p>
                  <% end %>

                  <div class="bg-white/10 rounded-lg p-3 backdrop-blur-sm">
                    <h6 class="text-xs font-bold text-white/70 mb-1">CREATIVE APPROACH:</h6>
                    <p class="text-sm text-white/90">
                      <%= @context || "Notice the attention to detail, composition, and technical execution demonstrating professional skill." %>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-12">
          <svg class="w-16 h-16 mx-auto mb-4 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <p class={[
            "text-sm",
            case @template_theme do
              :creative -> "text-white/70"
              :corporate -> "text-gray-500"
              :minimalist -> "text-gray-500"
            end
          ]}>
            Media showcase content will demonstrate creative work and technical skills
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  def render_case_study_card(assigns, section) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:project_title, Map.get(section.content || %{}, "project_title") || "Case Study Project")
      |> assign(:client, Map.get(section.content || %{}, "client"))
      |> assign(:overview, Map.get(section.content || %{}, "overview") || "Strategic case study demonstrating problem-solving methodology and results through analytical thinking.")
      |> assign(:problem_statement, Map.get(section.content || %{}, "problem_statement"))
      |> assign(:approach, Map.get(section.content || %{}, "approach"))
      |> assign(:results, Map.get(section.content || %{}, "results"))

    ~H"""
    <div class="space-y-6">
      <div>
        <h4 class={[
          "text-lg font-bold mb-2",
          case @template_theme do
            :creative -> "text-white"
            :corporate -> "text-gray-900"
            :minimalist -> "text-gray-900"
          end
        ]}>
          <%= @project_title %>
        </h4>

        <%= if @client do %>
          <p class={[
            "text-sm font-medium mb-3",
            case @template_theme do
              :creative -> "text-white/80"
              :corporate -> "text-blue-600"
              :minimalist -> "text-gray-600"
            end
          ]}>
            Client: <%= @client %>
          </p>
        <% end %>

        <p class={[
          "text-sm leading-relaxed",
          case @template_theme do
            :creative -> "text-white/90"
            :corporate -> "text-gray-700"
            :minimalist -> "text-gray-600"
          end
        ]}>
          <%= @overview %>
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= if @problem_statement do %>
          <div class={[
            "p-4 rounded-xl border-l-4",
            case @template_theme do
              :creative -> "bg-white/5 border-l-red-400"
              :corporate -> "bg-red-50 border-l-red-600"
              :minimalist -> "bg-gray-50 border-l-red-600"
            end
          ]}>
            <h5 class={[
              "font-bold text-sm mb-2",
              case @template_theme do
                :creative -> "text-white"
                :corporate -> "text-red-900"
                :minimalist -> "text-red-900"
              end
            ]}>
              Problem
            </h5>
            <p class={[
              "text-sm leading-relaxed",
              case @template_theme do
                :creative -> "text-white/80"
                :corporate -> "text-red-700"
                :minimalist -> "text-red-700"
              end
            ]}>
              <%= String.slice(@problem_statement, 0, 100) %>
              <%= if String.length(@problem_statement) > 100, do: "..." %>
            </p>
          </div>
        <% end %>

        <%= if @approach do %>
          <div class={[
            "p-4 rounded-xl border-l-4",
            case @template_theme do
              :creative -> "bg-white/5 border-l-green-400"
              :corporate -> "bg-green-50 border-l-green-600"
              :minimalist -> "bg-gray-50 border-l-green-600"
            end
          ]}>
            <h5 class={[
              "font-bold text-sm mb-2",
              case @template_theme do
                :creative -> "text-white"
                :corporate -> "text-green-900"
                :minimalist -> "text-green-900"
              end
            ]}>
              Approach
            </h5>
            <p class={[
              "text-sm leading-relaxed",
              case @template_theme do
                :creative -> "text-white/80"
                :corporate -> "text-green-700"
                :minimalist -> "text-green-700"
              end
            ]}>
              <%= String.slice(@approach, 0, 100) %>
              <%= if String.length(@approach) > 100, do: "..." %>
            </p>
          </div>
        <% end %>
      </div>

      <%= if @results do %>
        <div class={[
          "p-4 rounded-xl border-l-4",
          case @template_theme do
            :creative -> "bg-white/5 border-l-blue-400"
            :corporate -> "bg-blue-50 border-l-blue-600"
            :minimalist -> "bg-gray-50 border-l-blue-600"
          end
        ]}>
          <h5 class={[
            "font-bold text-sm mb-2",
            case @template_theme do
              :creative -> "text-white"
              :corporate -> "text-blue-900"
              :minimalist -> "text-blue-900"
            end
          ]}>
            Results & Impact
          </h5>
          <p class={[
            "text-sm leading-relaxed",
            case @template_theme do
              :creative -> "text-white/80"
              :corporate -> "text-blue-700"
              :minimalist -> "text-blue-700"
            end
          ]}>
            <%= String.slice(@results, 0, 120) %>
            <%= if String.length(@results) > 120, do: "..." %>
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  def render_generic_card(assigns, section) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:section_type_display, String.capitalize(to_string(section.section_type)) |> String.replace("_", " "))
      |> assign(:media_files, Map.get(section, :media_files, []))
      |> assign(:has_media, length(Map.get(section, :media_files, [])) > 0)

    ~H"""
    <div class="space-y-4">
      <p class={[
        "text-sm leading-relaxed",
        case @template_theme do
          :creative -> "text-white/90"
          :corporate -> "text-gray-700"
          :minimalist -> "text-gray-600"
        end
      ]}>
        This section showcases <%= @section_type_display %> content
        demonstrating professional expertise and experience.
      </p>

      <%= if @has_media do %>
        <div class="grid grid-cols-2 gap-3">
          <%= for media <- Enum.take(@media_files, 2) do %>
            <div class="relative group overflow-hidden rounded-lg aspect-video">
              <%= case Map.get(media, :media_type) do %>
                <% :image -> %>
                  <img src={get_media_url(media)} alt={Map.get(media, :title) || "Section media"}
                        class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                <% :video -> %>
                  <video class="w-full h-full object-cover" poster={get_video_thumbnail(media)}>
                    <source src={get_media_url(media)} type="video/mp4" />
                  </video>
                  <div class="absolute inset-0 flex items-center justify-center">
                    <div class="w-8 h-8 bg-black/60 rounded-full flex items-center justify-center">
                      <svg class="w-4 h-4 text-white ml-0.5" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                      </svg>
                    </div>
                  </div>
                <% _ -> %>
                  <div class="w-full h-full bg-gray-200 flex items-center justify-center">
                    <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                  </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <div class={[
        "p-4 rounded-xl border-l-4",
        case @template_theme do
          :creative -> "bg-white/5 border-l-purple-400"
          :corporate -> "bg-gray-50 border-l-gray-600"
          :minimalist -> "bg-gray-50 border-l-gray-900"
        end
      ]}>
        <h5 class={[
          "font-bold text-sm mb-2",
          case @template_theme do
            :creative -> "text-white"
            :corporate -> "text-gray-900"
            :minimalist -> "text-gray-900"
          end
        ]}>
          Professional Content
        </h5>
        <p class={[
          "text-sm leading-relaxed",
          case @template_theme do
            :creative -> "text-white/80"
            :corporate -> "text-gray-600"
            :minimalist -> "text-gray-600"
          end
        ]}>
          Comprehensive professional expertise and experience showcased through structured content and supporting materials.
        </p>
      </div>
    </div>
    """
  end

  # COLLABORATION HELPER FUNCTIONS
  def get_border_class(theme) do
    case theme do
      :creative -> "border-white/20"
      :corporate -> "border-gray-200"
      :minimalist -> "border-gray-200"
      _ -> "border-gray-200"
    end
  end

  def get_collaboration_bg_class(theme) do
    case theme do
      :creative -> "bg-white/10 border border-white/20"
      :corporate -> "bg-blue-50 border border-blue-200"
      :minimalist -> "bg-gray-50 border border-gray-200"
      _ -> "bg-blue-50 border border-blue-200"
    end
  end

  def get_collaboration_text_class(theme) do
    case theme do
      :creative -> "text-white"
      :corporate -> "text-blue-900"
      :minimalist -> "text-gray-900"
      _ -> "text-gray-900"
    end
  end

  def get_collaboration_button_class(theme) do
    case theme do
      :creative -> "bg-white/20 text-white hover:bg-white/30 border border-white/30"
      :corporate -> "bg-blue-600 text-white hover:bg-blue-700"
      :minimalist -> "bg-gray-900 text-white hover:bg-gray-800"
      _ -> "bg-blue-600 text-white hover:bg-blue-700"
    end
  end

  # ADDITIONAL HELPER FUNCTIONS
  def find_media_by_id(media_files, media_id) do
    Enum.find(media_files, &(&1.id == media_id))
  end

  # Template background classes
  def template_class(:creative, "bg"), do: "bg-gradient-to-br from-purple-600 via-blue-600 to-indigo-800"
  def template_class(:corporate, "bg"), do: "bg-gradient-to-br from-gray-50 to-blue-50"
  def template_class(:minimalist, "bg"), do: "bg-white"
  def template_class(_, "bg"), do: "bg-white"

  # Utility function for truncating text
  defp truncate_text(text, length \\ 120) when is_binary(text) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end
  defp truncate_text(nil, _length), do: ""
end
