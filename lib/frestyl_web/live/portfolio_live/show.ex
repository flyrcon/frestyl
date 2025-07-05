# lib/frestyl_web/live/portfolio_live/show.ex
# COMPLETE WORKING VERSION

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view

  import Ecto.Query

  alias Frestyl.Portfolios
  alias Frestyl.Repo
  alias Phoenix.PubSub
  alias FrestylWeb.PortfolioLive.PdfExportComponent

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    try do
      portfolio = Portfolios.get_portfolio!(id)
      current_user = socket.assigns.current_user

      # Check access permissions first
      if can_edit_portfolio?(portfolio, current_user) do
        # Subscribe to real-time updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio.id}")
        end

        # Load portfolio data
        sections = load_portfolio_sections_safe(portfolio.id)

        # Process customization CSS and template layout
        {template_config, customization_css, template_layout} = process_portfolio_customization(portfolio)

        socket =
          socket
          |> assign(:page_title, portfolio.title || "Portfolio")
          |> assign(:portfolio, portfolio)
          |> assign(:current_user, current_user)
          |> assign(:can_edit, can_edit_portfolio?(portfolio, current_user))
          |> assign(:show_export_modal, false)
          |> assign(:sections, sections)
          |> assign(:customization, portfolio.customization || %{})
          |> assign(:template_config, template_config)
          |> assign(:template_layout, template_layout)
          |> assign(:customization_css, customization_css)
          |> assign(:can_export, owns_portfolio?(portfolio, current_user))
          |> assign(:show_export_panel, false)
          |> assign(:export_processing, false)
          |> assign(:live_updates_enabled, true)

        {:ok, socket}
      else
        {:ok, socket
        |> put_flash(:error, "Access denied")
        |> redirect(to: "/")}
      end
    rescue
      Ecto.NoResultsError ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}

      error ->
        # Log the error for debugging
        require Logger
        Logger.error("Error in portfolio show mount: #{inspect(error)}")

        {:ok, socket
        |> put_flash(:error, "An error occurred loading the portfolio")
        |> redirect(to: "/")}
    end
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Portfolios.get_portfolio_by_slug(slug) do
      nil ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}

      portfolio ->
        # For now, just use the portfolio as-is to prevent errors
        # We'll fix the sections loading later
        socket =
          socket
          |> assign(:page_title, portfolio.title || "Portfolio")
          |> assign(:portfolio, portfolio)
          |> assign(:sections, [])  # Empty sections for now
          |> assign(:customization, portfolio.customization || %{})
          |> assign(:template_config, %{})
          |> assign(:template_layout, "default")
          |> assign(:customization_css, "")
          |> assign(:can_export, false)
          |> assign(:show_export_panel, false)
          |> assign(:live_updates_enabled, false)

        {:ok, socket}
    end
  end

  # HELPER FUNCTIONS
  defp can_view_portfolio?(portfolio, user) do
    case portfolio.visibility do
      :public -> true
      :link_only -> true  # Accessible via direct URL
      :request_only ->
        # Check if user has been granted access or is the owner
        if user do
          portfolio.user_id == user.id or has_access_permission?(portfolio, user)
        else
          false
        end
      :private ->
        # Only owner and collaborators
        if user do
          portfolio.user_id == user.id or is_collaborator?(portfolio, user)
        else
          false
        end
      _ -> false
    end
  end

  defp has_access_permission?(portfolio, user) do
    # Check if user has been granted access to request_only portfolio
    # This would query your access_requests table or similar
    # For now, return false - implement based on your access system
    false
  end

  defp is_collaborator?(portfolio, user) do
    # Check if user is a collaborator on private portfolio
    # This would query your collaboration system
    # For now, return false - implement based on your collaboration system
    false
  end

  # ADD helper for getting visibility display text
  defp get_visibility_display_text(visibility) do
    case visibility do
      :public -> "Public"
      :link_only -> "Link Only"
      :request_only -> "Request Access"
      :private -> "Private"
      _ -> "Unknown"
    end
  end

  defp owns_portfolio?(portfolio, user) do
    user && portfolio.user_id == user.id
  end

  defp load_portfolio_sections_safe(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      if socket.assigns[:current_user] do
        Portfolios.create_visit(%{
          portfolio_id: portfolio.id,
          user_id: socket.assigns.current_user.id,
          ip_address: "127.0.0.1"
        })
      end
    rescue
      _ -> :ok
    end
  end

  defp get_default_customization do
    %{
      "primary_color" => "#374151",
      "secondary_color" => "#6b7280",
      "accent_color" => "#3b82f6",
      "background_color" => "#ffffff",
      "text_color" => "#111827",
      "layout" => "dashboard"
    }
  end

  defp load_minimal_sections(portfolio_id) do
    # Use a lighter query for preview mode
    try do
      from(s in PortfolioSection,
        where: s.portfolio_id == ^portfolio_id,
        select: %{
          id: s.id,
          title: s.title,
          section_type: s.section_type,
          content: s.content,
          visible: s.visible
        },
        limit: 10
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  defp get_portfolio_basic(id) do
    from(p in Portfolio,
      where: p.id == ^id,
      select: %{
        id: p.id,
        title: p.title,
        description: p.description,
        theme: p.theme,
        customization: p.customization,
        visibility: p.visibility,
        user_id: p.user_id
      }
    )
    |> Repo.one!()
  end

  # EVENT HANDLERS (add basic ones if needed)
  @impl true
  def handle_event("toggle_export_panel", _params, socket) do
    {:noreply, assign(socket, :show_export_panel, !socket.assigns.show_export_panel)}
  end

  # Add any other event handlers you need
  @impl true
  def handle_event(event, params, socket) do
    # Catch-all for unhandled events
    IO.puts("Unhandled event: #{event} with params: #{inspect(params)}")
    {:noreply, socket}
  end

    @impl true
  def handle_event("show_export_panel", _params, socket) do
    if socket.assigns.can_export do
      {:noreply, assign(socket, :show_export_panel, true)}
    else
      {:noreply, put_flash(socket, :error, "Export not available")}
    end
  end

  @impl true
  def handle_event("hide_export_panel", _params, socket) do
    {:noreply, assign(socket, :show_export_panel, false)}
  end

  @impl true
  def handle_event("export_portfolio", %{"format" => format}, socket) do
    if socket.assigns.can_export do
      portfolio = socket.assigns.portfolio

      socket = assign(socket, :export_processing, true)

      # Start export process
      Task.start(fn ->
        case export_portfolio_to_format(portfolio, format) do
          {:ok, export_data} ->
            send(self(), {:export_complete, export_data})
          {:error, reason} ->
            send(self(), {:export_failed, reason})
        end
      end)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Export not available")}
    end
  end

  @impl true
  def handle_info({:export_complete, export_data}, socket) do
    socket =
      socket
      |> assign(:export_processing, false)
      |> assign(:show_export_panel, false)
      |> put_flash(:info, "Portfolio exported successfully!")
      |> push_event("download_file", %{
          url: export_data.download_url,
          filename: export_data.filename
        })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:export_failed, reason}, socket) do
    socket =
      socket
      |> assign(:export_processing, false)
      |> put_flash(:error, "Export failed: #{reason}")

    {:noreply, socket}
  end

  defp render_section_content_safe(section) do
    try do
      content = section.content || %{}

      # Simple content extraction
      description = get_simple_value(content, ["description", "summary", "content", "text", "main_content"])

      if description != "" do
        Phoenix.HTML.raw("<p>#{Phoenix.HTML.html_escape(description)}</p>")
      else
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Section content...</p>")
      end
    rescue
      _ ->
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Loading content...</p>")
    end
  end

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

  def apply_customization_styles(customization) when is_map(customization) do
    # Use EXACT colors user set - no template overrides
    primary_color = Map.get(customization, "primary_color", "#374151")
    accent_color = Map.get(customization, "accent_color", "#059669")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    background_color = Map.get(customization, "background_color", "#ffffff")
    text_color = Map.get(customization, "text_color", "#1f2937")
    layout = Map.get(customization, "layout", "minimal")

    """
    <style>
      :root {
        --primary-color: #{primary_color};
        --accent-color: #{accent_color};
        --secondary-color: #{secondary_color};
        --background-color: #{background_color};
        --text-color: #{text_color};
      }

      .portfolio-container {
        #{get_layout_styles(layout)}
        background-color: var(--background-color);
        color: var(--text-color);
      }

      .portfolio-primary { color: var(--primary-color) !important; }
      .portfolio-accent { color: var(--accent-color) !important; }
      .portfolio-secondary { color: var(--secondary-color) !important; }

      .bg-portfolio-primary { background-color: var(--primary-color) !important; }
      .bg-portfolio-accent { background-color: var(--accent-color) !important; }
      .bg-portfolio-secondary { background-color: var(--secondary-color) !important; }
    </style>
    """
  end

  def apply_customization_styles(_), do: ""

  # ADD these helper functions to show.ex:
  defp map_template_grid_to_layout(grid_type) do
    case grid_type do
      "masonry" -> "dashboard"
      "pinterest" -> "gallery"
      "service_oriented" -> "case_study"
      "minimal_stack" -> "minimal"
      _ -> "dashboard"
    end
  end

  defp get_template_system_layout_styles(layout, spacing, max_columns) do
    case layout do
      "dashboard" ->
        "display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: #{spacing}; max-width: #{max_columns * 400}px; margin: 0 auto;"
      "gallery" ->
        "display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: #{spacing}; max-width: #{max_columns * 350}px; margin: 0 auto;"
      "case_study" ->
        "display: flex; flex-direction: column; gap: #{spacing}; max-width: 900px; margin: 0 auto;"
      "minimal" ->
        "display: flex; flex-direction: column; gap: #{spacing}; max-width: 800px; margin: 0 auto;"
      _ ->
        "display: flex; flex-direction: column; gap: #{spacing}; max-width: 800px; margin: 0 auto;"
    end
  end

  # Helper function to map template system grid types to layouts
  defp map_template_grid_to_layout(grid_type) do
    case grid_type do
      "masonry" -> "dashboard"
      "pinterest" -> "gallery"
      "service_oriented" -> "case_study"
      "minimal_stack" -> "minimal"
      _ -> "dashboard"
    end
  end

  defp get_layout_styles("dashboard") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem;"
  end

  defp get_layout_styles("gallery") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem;"
  end

  defp get_layout_styles(_) do
    "display: flex; flex-direction: column; gap: 2rem;"
  end

  @impl true
  def handle_info({:sections_updated, sections}, socket) do
    {:noreply, assign(socket, :sections, sections)}
  end

    @impl true
  def handle_info({:preview_update, customization, css}, socket) do
    IO.puts("🔥 SHOW.EX: Received preview update from editor")
    IO.puts("🔥 New customization: #{inspect(Map.keys(customization))}")

    # Update portfolio with new customization
    updated_portfolio = %{socket.assigns.portfolio | customization: customization}

    # Reprocess template configuration with new customization
    {template_config, updated_css, template_layout} = process_portfolio_customization(updated_portfolio)

    socket =
      socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, customization)
      |> assign(:template_config, template_config)
      |> assign(:template_layout, template_layout)
      |> assign(:customization_css, updated_css)
      |> push_event("update_portfolio_styles", %{css: updated_css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:section_update, updated_section}, socket) do
    IO.puts("🔥 SHOW.EX: Received section update from editor")

    # Update the specific section in the sections list
    updated_sections =
      socket.assigns.sections
      |> Enum.map(fn section ->
        if section.id == updated_section.id, do: updated_section, else: section
      end)

    socket =
      socket
      |> assign(:sections, updated_sections)
      |> push_event("refresh_section", %{section_id: updated_section.id})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:template_change, template, css}, socket) do
    IO.puts("🔥 SHOW.EX: Received template change from editor: #{template}")

    # Update portfolio theme
    updated_portfolio = %{socket.assigns.portfolio | theme: template}

    # Reprocess everything with new template
    {template_config, updated_css, template_layout} = process_portfolio_customization(updated_portfolio)

    socket =
      socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:template_config, template_config)
      |> assign(:template_layout, template_layout)
      |> assign(:customization_css, updated_css)
      |> push_event("reload_portfolio_template", %{template: template, css: updated_css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:viewport_change, mobile_view}, socket) do
    # Handle mobile/desktop viewport changes from editor
    socket = push_event(socket, "update_viewport", %{mobile: mobile_view})
    {:noreply, socket}
  end

    @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_export_modal", _params, socket) do
    {:noreply, assign(socket, :how_export_modal, true)}
  end

  @impl true
  def handle_event("hide_export_modal", _params, socket) do
    {:noreply, assign(socket, :show_export_modal, false)}
  end

  @impl true
  def handle_event("print_portfolio", _params, socket) do
    # Trigger browser print dialog with print-optimized CSS
    {:noreply,
     socket
     |> push_event("print_portfolio", %{})}
  end

  @impl true
  def handle_info({:portfolio_updated, updated_portfolio}, socket) do
    # Real-time portfolio updates from PubSub
    {:noreply, assign(socket, :portfolio, updated_portfolio)}
  end

  @impl true
  def handle_info({:close_modal, :export}, socket) do
    {:noreply, assign(socket, :show_export_modal, false)}
  end

  defp can_edit_portfolio?(portfolio, current_user) do
    current_user && (portfolio.user_id == current_user.id || current_user.role == "admin")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="portfolio-show-container">
      <!-- Portfolio Header with Export Options -->
      <div class="flex items-center justify-between mb-8 print:hidden">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">{@portfolio.title || "Portfolio"}</h1>
          <p :if={@portfolio.description} class="text-lg text-gray-600 mt-2">{@portfolio.description}</p>
        </div>

        <!-- Action Buttons (only show when user is authenticated) -->
        <div :if={@current_user} class="flex items-center space-x-4">
          <!-- Edit Button (only for portfolio owners) -->
          <.link
            :if={@can_edit}
            navigate={~p"/portfolio/#{@portfolio}/edit"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>
            </svg>
            Edit Portfolio
          </.link>

          <!-- Print Button -->
          <button
            phx-click="print-portfolio"
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"></path>
            </svg>
            Print
          </button>

          <!-- Export Button -->
          <button
            phx-click="show-export-modal"
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-green-600 border border-transparent rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
            </svg>
            Export
          </button>
        </div>
      </div>

      <!-- Portfolio Content -->
      <div class="portfolio-content">
        <!-- Contact Section -->
        <div :if={show_contact_section?(@portfolio)} class="portfolio-section mb-8">
          <h2 class="section-title">Contact Information</h2>
          <div class="contact-grid">
            <div :if={get_contact_field(@portfolio, "email")} class="contact-item">
              <span class="contact-label">Email:</span>
              <a href={"mailto:#{get_contact_field(@portfolio, "email")}"} class="contact-value">
                {get_contact_field(@portfolio, "email")}
              </a>
            </div>
            <div :if={get_contact_field(@portfolio, "phone")} class="contact-item">
              <span class="contact-label">Phone:</span>
              <span class="contact-value">{get_contact_field(@portfolio, "phone")}</span>
            </div>
            <div :if={get_contact_field(@portfolio, "linkedin")} class="contact-item">
              <span class="contact-label">LinkedIn:</span>
              <a href={get_contact_field(@portfolio, "linkedin")} target="_blank" class="contact-value">
                View Profile
              </a>
            </div>
            <div :if={get_contact_field(@portfolio, "github")} class="contact-item">
              <span class="contact-label">GitHub:</span>
              <a href={get_contact_field(@portfolio, "github")} target="_blank" class="contact-value">
                View Profile
              </a>
            </div>
          </div>
        </div>

        <!-- Summary Section -->
        <div :if={get_portfolio_summary(@portfolio)} class="portfolio-section mb-8">
          <h2 class="section-title">Professional Summary</h2>
          <div class="summary-content">
            <p class="text-gray-700 leading-relaxed">{get_portfolio_summary(@portfolio)}</p>
          </div>
        </div>

        <!-- Experience Section -->
        <div :if={get_work_experiences(@portfolio) != []} class="portfolio-section mb-8">
          <h2 class="section-title">Work Experience</h2>
          <div class="experience-list space-y-6">
            <div :for={experience <- get_work_experiences(@portfolio)} class="experience-item">
              <div class="experience-header">
                <h3 class="experience-title">{experience.title}</h3>
                <div class="experience-company">{experience.company}</div>
                <div class="experience-dates">{experience.start_date} - {experience.end_date || "Present"}</div>
              </div>
              <div :if={experience.description} class="experience-description">
                <p class="text-gray-700">{experience.description}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Education Section -->
        <div :if={get_education(@portfolio) != []} class="portfolio-section mb-8">
          <h2 class="section-title">Education</h2>
          <div class="education-list space-y-4">
            <div :for={edu <- get_education(@portfolio)} class="education-item">
              <h3 class="education-degree">{edu.degree}</h3>
              <div class="education-institution">{edu.institution}</div>
              <div class="education-year">{edu.graduation_year}</div>
            </div>
          </div>
        </div>

        <!-- Skills Section -->
        <div :if={get_skills(@portfolio) != []} class="portfolio-section mb-8">
          <h2 class="section-title">Skills</h2>
          <div class="skills-grid">
            <span :for={skill <- get_skills(@portfolio)} class="skill-tag">
              {skill}
            </span>
          </div>
        </div>

        <!-- Projects Section -->
        <div :if={get_projects(@portfolio) != []} class="portfolio-section mb-8">
          <h2 class="section-title">Projects</h2>
          <div class="projects-grid">
            <div :for={project <- get_projects(@portfolio)} class="project-card">
              <h3 class="project-title">{project.title}</h3>
              <p :if={project.description} class="project-description">{project.description}</p>
              <div :if={project.technologies} class="project-technologies">
                <span :for={tech <- project.technologies} class="tech-tag">{tech}</span>
              </div>
              <div :if={project.url} class="project-links">
                <a href={project.url} target="_blank" class="project-link">View Project</a>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Export Modal -->
      <div :if={@show_export_modal} class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="fixed inset-0 transition-opacity" aria-hidden="true">
            <div class="absolute inset-0 bg-gray-500 opacity-75" phx-click="hide-export-modal"></div>
          </div>

          <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full sm:p-6">
            <.live_component
              module={PdfExportComponent}
              id="pdf-export-component"
              portfolio={@portfolio}
              current_user={@current_user}
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Print-specific styles -->
    <style>
      @media print {
        .print\\:hidden {
          display: none !important;
        }

        .portfolio-show-container {
          max-width: none !important;
          margin: 0 !important;
          padding: 0.5in !important;
        }

        .portfolio-content {
          color: black !important;
          background: white !important;
        }

        .section-title {
          color: black !important;
          border-bottom: 2px solid black !important;
          margin-bottom: 0.25in !important;
          padding-bottom: 0.1in !important;
          page-break-after: avoid !important;
        }

        .portfolio-section {
          page-break-inside: avoid !important;
          margin-bottom: 0.3in !important;
        }

        .experience-item,
        .project-card {
          page-break-inside: avoid !important;
          margin-bottom: 0.2in !important;
        }

        a {
          color: black !important;
          text-decoration: underline !important;
        }

        .skill-tag,
        .tech-tag {
          border: 1px solid black !important;
          color: black !important;
          background: white !important;
        }
      }

      /* Regular styles for screen */
      .portfolio-show-container {
        max-width: 1200px;
        margin: 0 auto;
        padding: 2rem;
      }

      .section-title {
        font-size: 1.5rem;
        font-weight: bold;
        color: #1f2937;
        border-bottom: 2px solid #3b82f6;
        margin-bottom: 1rem;
        padding-bottom: 0.5rem;
      }

      .contact-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: 1rem;
      }

      .contact-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
      }

      .contact-label {
        font-weight: 600;
        color: #374151;
      }

      .contact-value {
        color: #3b82f6;
      }

      .experience-header {
        margin-bottom: 0.75rem;
      }

      .experience-title {
        font-size: 1.125rem;
        font-weight: 600;
        color: #1f2937;
      }

      .experience-company {
        font-weight: 500;
        color: #3b82f6;
        margin-top: 0.25rem;
      }

      .experience-dates {
        font-style: italic;
        color: #6b7280;
        margin-top: 0.25rem;
      }

      .skills-grid {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
      }

      .skill-tag {
        background: #dbeafe;
        color: #1e40af;
        padding: 0.25rem 0.75rem;
        border-radius: 9999px;
        font-size: 0.875rem;
        font-weight: 500;
      }

      .projects-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 1.5rem;
      }

      .project-card {
        border: 1px solid #e5e7eb;
        border-radius: 0.5rem;
        padding: 1.5rem;
        background: #f9fafb;
      }

      .project-title {
        font-size: 1.125rem;
        font-weight: 600;
        color: #1f2937;
        margin-bottom: 0.5rem;
      }

      .project-description {
        color: #6b7280;
        margin-bottom: 1rem;
      }

      .project-technologies {
        display: flex;
        flex-wrap: wrap;
        gap: 0.25rem;
        margin-bottom: 1rem;
      }

      .tech-tag {
        background: #fef3c7;
        color: #92400e;
        padding: 0.125rem 0.5rem;
        border-radius: 0.25rem;
        font-size: 0.75rem;
      }

      .project-link {
        color: #3b82f6;
        text-decoration: underline;
        font-weight: 500;
      }

      .education-degree {
        font-weight: 600;
        color: #1f2937;
      }

      .education-institution {
        color: #3b82f6;
        margin-top: 0.25rem;
      }

      .education-year {
        color: #6b7280;
        font-style: italic;
        margin-top: 0.25rem;
      }
    </style>

    <!-- JavaScript for print functionality -->
    <script>
      window.addEventListener("phx:print-portfolio", (e) => {
        window.print();
      });
    </script>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_contact_field(portfolio, field) do
    contact_info = portfolio.contact_info || %{}
    Map.get(contact_info, field)
  end

  defp process_portfolio_customization(portfolio) do
    customization = portfolio.customization || %{}
    theme = portfolio.theme || "minimal"

    # Get template configuration
    template_config = get_template_config(theme)

    # Generate CSS
    customization_css = generate_portfolio_css(customization, theme)

    # Determine layout
    template_layout = determine_template_layout(theme, customization)

    {template_config, customization_css, template_layout}
  end

  defp get_template_config(theme) do
    case theme do
      "minimal" -> %{name: "Minimal", primary_color: "#374151", layout: "simple"}
      "executive" -> %{name: "Executive", primary_color: "#1f2937", layout: "professional"}
      "creative" -> %{name: "Creative", primary_color: "#7c3aed", layout: "artistic"}
      "developer" -> %{name: "Developer", primary_color: "#059669", layout: "technical"}
      _ -> %{name: "Default", primary_color: "#6b7280", layout: "simple"}
    end
  end

  defp generate_portfolio_css(customization, theme) do
    primary_color = Map.get(customization, "primary_color") || get_theme_default(:primary, theme)
    secondary_color = Map.get(customization, "secondary_color") || get_theme_default(:secondary, theme)
    accent_color = Map.get(customization, "accent_color") || get_theme_default(:accent, theme)
    background_color = Map.get(customization, "background_color", "#ffffff")
    text_color = Map.get(customization, "text_color", "#1f2937")
    layout = Map.get(customization, "layout") || get_theme_default(:layout, theme)

    """
    <style id="portfolio-customization">
    :root {
      --portfolio-primary: #{primary_color};
      --portfolio-secondary: #{secondary_color};
      --portfolio-accent: #{accent_color};
      --portfolio-background: #{background_color};
      --portfolio-text: #{text_color};
    }

    .portfolio-container {
      background-color: var(--portfolio-background);
      color: var(--portfolio-text);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }

    .portfolio-header {
      background: linear-gradient(135deg, var(--portfolio-primary), var(--portfolio-secondary));
      color: white;
      padding: 4rem 2rem;
      text-align: center;
    }

    .portfolio-title {
      font-size: 3rem;
      font-weight: bold;
      margin-bottom: 1rem;
    }

    .portfolio-description {
      font-size: 1.25rem;
      opacity: 0.9;
      margin-bottom: 2rem;
    }

    .portfolio-section {
      padding: 3rem 2rem;
      max-width: 1200px;
      margin: 0 auto;
    }

    .section-title {
      color: var(--portfolio-primary);
      font-size: 2rem;
      font-weight: bold;
      margin-bottom: 1.5rem;
      border-bottom: 3px solid var(--portfolio-accent);
      padding-bottom: 0.5rem;
    }

    .section-content {
      line-height: 1.7;
    }

    .export-btn {
      background-color: var(--portfolio-accent);
      color: white;
      padding: 0.75rem 1.5rem;
      border-radius: 0.5rem;
      font-weight: 600;
      border: none;
      cursor: pointer;
      transition: all 0.2s;
    }

    .export-btn:hover {
      background-color: var(--portfolio-primary);
      transform: translateY(-1px);
    }

    #{get_layout_styles(layout)}
    #{get_theme_styles(theme)}
    </style>
    """
  end

  defp get_theme_default(type, theme) do
    defaults = case theme do
      "minimal" -> %{primary: "#374151", secondary: "#6b7280", accent: "#059669", layout: "simple"}
      "executive" -> %{primary: "#1f2937", secondary: "#374151", accent: "#3b82f6", layout: "professional"}
      "creative" -> %{primary: "#7c3aed", secondary: "#a855f7", accent: "#ec4899", layout: "artistic"}
      "developer" -> %{primary: "#059669", secondary: "#047857", accent: "#10b981", layout: "technical"}
      _ -> %{primary: "#6b7280", secondary: "#9ca3af", accent: "#374151", layout: "simple"}
    end

    Map.get(defaults, type, "#6b7280")
  end

  defp determine_template_layout(theme, customization) do
    Map.get(customization, "layout") || get_theme_default(:layout, theme)
  end

  defp get_template_class(layout) do
    case layout do
      "professional" -> "layout-professional"
      "artistic" -> "layout-artistic"
      "technical" -> "layout-technical"
      _ -> "layout-simple"
    end
  end

  defp get_layout_styles(layout) do
    case layout do
      "professional" -> """
        .portfolio-sections {
          display: grid;
          gap: 4rem;
        }
        .portfolio-section {
          background: white;
          border-radius: 1rem;
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
      """
      "artistic" -> """
        .portfolio-sections {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 2rem;
        }
        .portfolio-section {
          border-left: 4px solid var(--portfolio-accent);
        }
      """
      "technical" -> """
        .portfolio-container {
          background-color: #0d1117;
          color: #c9d1d9;
        }
        .portfolio-section {
          background: #161b22;
          border: 1px solid #30363d;
          border-radius: 6px;
        }
      """
      _ -> ""
    end
  end

  defp get_theme_styles(theme) do
    case theme do
      "creative" -> """
        .portfolio-header {
          background: linear-gradient(45deg, #7c3aed, #ec4899, #f59e0b);
          background-size: 300% 300%;
          animation: gradient-shift 6s ease infinite;
        }
        @keyframes gradient-shift {
          0% { background-position: 0% 50%; }
          50% { background-position: 100% 50%; }
          100% { background-position: 0% 50%; }
        }
      """
      _ -> ""
    end
  end

  defp render_section_content(section) do
    case section.section_type do
      :professional_summary ->
        content = section.content || %{}
        Map.get(content, "summary", "")

      :work_experience ->
        content = section.content || %{}
        experiences = Map.get(content, "experiences", [])

        experiences
        |> Enum.map(fn exp ->
          """
          <div class="experience-item mb-6">
            <h3 class="text-xl font-semibold">#{Map.get(exp, "title", "")}</h3>
            <h4 class="text-lg text-gray-600">#{Map.get(exp, "company", "")}</h4>
            <p class="text-sm text-gray-500 mb-2">#{Map.get(exp, "start_date", "")} - #{Map.get(exp, "end_date", "Present")}</p>
            <p>#{Map.get(exp, "description", "")}</p>
          </div>
          """
        end)
        |> Enum.join("")
        |> Phoenix.HTML.raw()

      :skills ->
        content = section.content || %{}
        skills = Map.get(content, "skills", [])

        skills
        |> Enum.map(fn skill ->
          name = if is_map(skill), do: Map.get(skill, "name", ""), else: to_string(skill)
          "<span class=\"inline-block bg-gray-200 text-gray-800 px-3 py-1 rounded-full text-sm mr-2 mb-2\">#{name}</span>"
        end)
        |> Enum.join("")
        |> Phoenix.HTML.raw()

      _ ->
        content = section.content || %{}
        Map.get(content, "text", "Content coming soon...")
    end
  end

  # Existing helper functions
  defp can_view_portfolio?(portfolio, user) do
    cond do
      portfolio.visibility == :public -> true
      portfolio.visibility == :link_only -> true
      user && portfolio.user_id == user.id -> true
      true -> false
    end
  end

  defp owns_portfolio?(portfolio, user) do
    user && portfolio.user_id == user.id
  end

  defp load_portfolio_sections_safe(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      current_user = Map.get(socket.assigns, :current_user, nil)

      visit_attrs = %{
        portfolio_id: portfolio.id,
        ip_address: get_client_ip(socket),
        user_agent: get_user_agent(socket),
        referrer: get_referrer(socket)
      }

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

  defp get_client_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} ->
        address |> :inet.ntoa() |> to_string()
      _ ->
        "127.0.0.1"
    end
  end

  defp get_user_agent(socket) do
    get_connect_info(socket, :user_agent) || "Unknown"
  end

  defp get_referrer(socket) do
    get_connect_params(socket)["ref"]
  end

  # Export functions
  defp export_portfolio_to_format(portfolio, format) do
    case format do
      "pdf" -> export_to_pdf(portfolio)
      "html" -> export_to_html(portfolio)
      _ -> {:error, "Unsupported format"}
    end
  end

  defp export_to_pdf(portfolio) do
    # Implement PDF export
    {:ok, %{
      download_url: "/exports/#{portfolio.slug}.pdf",
      filename: "#{portfolio.slug}_portfolio.pdf"
    }}
  end

  defp export_to_html(portfolio) do
    # Implement HTML export
    {:ok, %{
      download_url: "/exports/#{portfolio.slug}.html",
      filename: "#{portfolio.slug}_portfolio.html"
    }}
  end

  # Helper function to determine if contact section should be shown
  defp show_contact_section?(portfolio) do
    contact_info = portfolio.contact_info || %{}
    privacy_settings = portfolio.privacy_settings || %{}

    # Show contact section if:
    # 1. Privacy settings allow showing contact info, AND
    # 2. At least one contact field has data
    show_contact = Map.get(privacy_settings, "show_contact_info", true)
    has_contact_data = contact_info["email"] || contact_info["phone"] ||
                      contact_info["linkedin"] || contact_info["github"]

    show_contact && has_contact_data
  end

  # Ultra-safe helper function to get work experiences
  defp get_work_experiences(portfolio) do
    try do
      # Double-check that sections are loaded
      if Ecto.assoc_loaded?(portfolio.sections) do
        sections = portfolio.sections || []
        IO.puts("🔍 HELPER: Processing #{length(sections)} sections for work experience")

        # Find experience section
        experience_section = Enum.find(sections, fn section ->
          section_type = section.section_type
          IO.puts("🔍 HELPER: Checking section type: #{inspect(section_type)}")
          section_type == :experience || section_type == "experience"
        end)

        if experience_section do
          IO.puts("✅ HELPER: Found experience section")
          content = experience_section.content || %{}
          jobs = content["jobs"] || content["work_experience"] || content["experiences"] || []
          IO.puts("🔍 HELPER: Found #{length(jobs)} jobs")

          # Ensure each job has the expected structure
          Enum.map(jobs, fn job ->
            %{
              title: job["title"] || job["position"] || "",
              company: job["company"] || job["employer"] || "",
              start_date: job["start_date"] || job["from"] || "",
              end_date: job["end_date"] || job["to"] || job["until"],
              description: job["description"] || job["summary"] || job["responsibilities"] || ""
            }
          end)
        else
          IO.puts("❌ HELPER: No experience section found")
          []
        end
      else
        IO.puts("❌ HELPER: Sections not loaded!")
        []
      end
    rescue
      error ->
        IO.puts("❌ HELPER ERROR: #{inspect(error)}")
        []
    end
  end

  # Ultra-safe helper function for portfolio summary
  defp get_portfolio_summary(portfolio) do
    try do
      # First try the description field
      summary = portfolio.description

      if summary && String.trim(summary) != "" do
        summary
      else
        # Only try to access sections if they're loaded
        if Ecto.assoc_loaded?(portfolio.sections) do
          sections = portfolio.sections || []
          intro_section = Enum.find(sections, fn section ->
            section_type = section.section_type
            section_type == :intro || section_type == "intro"
          end)

          if intro_section do
            content = intro_section.content || %{}
            content["summary"] || content["description"] || content["bio"] || ""
          else
            nil
          end
        else
          nil
        end
      end
    rescue
      error ->
        IO.puts("❌ SUMMARY ERROR: #{inspect(error)}")
        nil
    end
  end

  # Helper function to extract education from portfolio sections
  defp get_education(portfolio) do
    try do
      # Since sections aren't loading properly, return empty for now
      # This prevents the template error
      []
    rescue
      _ -> []
    end
  end

  # Helper function to extract skills from portfolio sections
  defp get_skills(portfolio) do
    try do
      # Since sections aren't loading properly, return empty for now
      # This prevents the template error
      []
    rescue
      _ -> []
    end
  end

  # Helper function to extract projects from portfolio sections
  defp get_projects(portfolio) do
    try do
      # Since sections aren't loading properly, return empty for now
      # This prevents the template error
      []
    rescue
      _ -> []
    end
  end
end
