# lib/frestyl_web/live/portfolio_live/live_preview.ex
# FIXED VERSION - Using the new CSS generation system

defmodule FrestylWeb.PortfolioLive.LivePreview do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias FrestylWeb.PortfolioLive.{CssGenerator, CssPriorityManager}
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => portfolio_id} = params, _session, socket) do
    IO.puts("🔥 LIVE PREVIEW MOUNT: portfolio_id=#{portfolio_id}")

    # Verify preview token if present
    if preview_token = params["preview_token"] do
      unless verify_preview_token(portfolio_id, preview_token) do
        {:ok, socket |> put_flash(:error, "Invalid preview session") |> redirect(to: "/")}
      end
    end

    case Portfolios.get_portfolio(portfolio_id) do
      {:ok, portfolio} ->
        IO.puts("🔥 PORTFOLIO LOADED: #{portfolio.title}")

        # Subscribe to live preview updates
        PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")

        # Load sections with proper content structure
        sections = load_portfolio_sections_enhanced(portfolio.id)
        IO.puts("🔥 SECTIONS LOADED: #{length(sections)} sections")

        # Get customization from params or portfolio
        customization = build_customization_from_params(params, portfolio)

        # UPDATED: Use CssPriorityManager for guaranteed user customization priority
        mobile_view = params["mobile"] == "true"
        temp_portfolio = %{portfolio | customization: customization}
        preview_css = CssPriorityManager.generate_portfolio_css(temp_portfolio,
          mobile_view: mobile_view,
          preview_mode: true
        )

        socket =
          socket
          |> assign(:portfolio, portfolio)
          |> assign(:preview_mode, true)
          |> assign(:mobile_view, mobile_view)
          |> assign(:viewport_width, if(mobile_view, do: "375px", else: "100%"))
          |> assign(:customization, customization)
          |> assign(:preview_css, preview_css)
          |> assign(:sections, sections)
          |> assign(:owner, portfolio.user)

        {:ok, socket}

      {:error, _} ->
        # Fall back to old method for backward compatibility
        try do
          portfolio = Portfolios.get_portfolio!(portfolio_id)

          sections = load_portfolio_sections_enhanced(portfolio.id)
          customization = build_customization_from_params(params, portfolio)
          mobile_view = params["mobile"] == "true"

          # UPDATED: Use CssPriorityManager here too
          temp_portfolio = %{portfolio | customization: customization}
          preview_css = CssPriorityManager.generate_portfolio_css(temp_portfolio,
            mobile_view: mobile_view,
            preview_mode: true
          )

          socket =
            socket
            |> assign(:portfolio, portfolio)
            |> assign(:preview_mode, true)
            |> assign(:mobile_view, mobile_view)
            |> assign(:viewport_width, if(mobile_view, do: "375px", else: "100%"))
            |> assign(:customization, customization)
            |> assign(:preview_css, preview_css)
            |> assign(:sections, sections)
            |> assign(:owner, portfolio.user)

          {:ok, socket}
        rescue
          _ ->
            {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
        end
    end
  end

  @impl true
  def handle_info({:preview_update, new_customization, portfolio}, socket) do
    IO.puts("🔥 PREVIEW UPDATE WITH PORTFOLIO RECEIVED")

    # Regenerate CSS with new customization
    new_css = CssGenerator.generate_portfolio_css(portfolio, mobile_view: socket.assigns.mobile_view)

    socket =
      socket
      |> assign(:customization, new_customization)
      |> assign(:portfolio, portfolio)
      |> assign(:preview_css, new_css)
      |> push_event("update_preview_styles", %{css: new_css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:viewport_change, mobile_view}, socket) do
    IO.puts("🔥 VIEWPORT CHANGE: mobile=#{mobile_view}")

    # UPDATED: Regenerate CSS for new viewport using CssPriorityManager
    new_css = CssPriorityManager.generate_portfolio_css(socket.assigns.portfolio,
      mobile_view: mobile_view,
      preview_mode: true
    )
    viewport_width = if mobile_view, do: "375px", else: "100%"

    socket =
      socket
      |> assign(:mobile_view, mobile_view)
      |> assign(:viewport_width, viewport_width)
      |> assign(:preview_css, new_css)

    {:noreply, socket}
  end

  def handle_info({:sections_updated, sections}, socket) do
    IO.puts("🔥 SECTIONS UPDATED: #{length(sections)} sections")

    # Process sections to ensure proper structure
    processed_sections = process_sections_for_display(sections)

    {:noreply, assign(socket, :sections, processed_sections)}
  end

  # Helper functions
  defp verify_preview_token(portfolio_id, token) do
    expected_token = :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
                     |> Base.encode16(case: :lower)
                     |> String.slice(0, 16)

    token == expected_token
  end

  def render_section_content(section) do
    case section.section_type do
      :intro -> render_intro_content(section.content)
      :experience -> render_experience_content(section.content)
      :education -> render_education_content(section.content)
      :skills -> render_skills_content(section.content)
      :projects -> render_projects_content(section.content)
      :featured_project -> render_featured_project_content(section.content)
      :case_study -> render_case_study_content(section.content)
      :achievements -> render_achievements_content(section.content)
      :testimonial -> render_testimonial_content(section.content)
      :media_showcase -> render_media_content(section.content)
      :contact -> render_contact_content(section.content)
      _ -> render_generic_content(section.content)
    end
  end

  defp render_intro_content(content) do
    headline = Map.get(content, "headline", "Welcome")
    summary = Map.get(content, "summary", "")

    """
    <div class="intro-section">
      <h3 class="text-xl font-semibold mb-3 text-primary">#{escape_html(headline)}</h3>
      <p class="text-gray-600">#{escape_html(summary)}</p>
    </div>
    """
  end

  defp render_experience_content(content) do
    jobs = Map.get(content, "jobs", [])

    if length(jobs) > 0 do
      job_html = Enum.map_join(jobs, "", fn job ->
        title = Map.get(job, "title", "Position")
        company = Map.get(job, "company", "Company")
        description = Map.get(job, "description", "")

        """
        <div class="experience-item mb-4 p-3 border-l-4 border-accent">
          <h4 class="font-semibold text-primary">#{escape_html(title)}</h4>
          <p class="text-gray-600 font-medium">#{escape_html(company)}</p>
          <p class="text-sm text-gray-500 mt-1">#{escape_html(description)}</p>
        </div>
        """
      end)

      """
      <div class="experience-section">
        #{job_html}
      </div>
      """
    else
      """
      <div class="experience-section text-gray-500">
        <p>Experience details will appear here once configured.</p>
      </div>
      """
    end
  end

  defp render_education_content(content) do
    education = Map.get(content, "education", [])

    if length(education) > 0 do
      edu_html = Enum.map_join(education, "", fn edu ->
        degree = Map.get(edu, "degree", "Degree")
        institution = Map.get(edu, "institution", "Institution")

        """
        <div class="education-item mb-3">
          <h4 class="font-semibold text-primary">#{escape_html(degree)}</h4>
          <p class="text-gray-600">#{escape_html(institution)}</p>
        </div>
        """
      end)

      """
      <div class="education-section">
        #{edu_html}
      </div>
      """
    else
      """
      <div class="education-section text-gray-500">
        <p>Education details will appear here once configured.</p>
      </div>
      """
    end
  end

  defp render_skills_content(content) do
    skills = Map.get(content, "skills", [])

    if length(skills) > 0 do
      skills_html = Enum.map_join(skills, "", fn skill ->
        name = if is_map(skill), do: Map.get(skill, "name", "Skill"), else: skill

        """
        <span class="inline-block bg-accent bg-opacity-10 text-accent px-3 py-1 rounded-full text-sm mr-2 mb-2 border border-accent border-opacity-20">#{escape_html(name)}</span>
        """
      end)

      """
      <div class="skills-section">
        #{skills_html}
      </div>
      """
    else
      """
      <div class="skills-section text-gray-500">
        <p>Skills will appear here once configured.</p>
      </div>
      """
    end
  end

  defp render_projects_content(content) do
    projects = Map.get(content, "projects", [])

    if length(projects) > 0 do
      projects_html = Enum.map_join(projects, "", fn project ->
        title = Map.get(project, "title", "Project")
        description = Map.get(project, "description", "")

        """
        <div class="project-item mb-4 p-4 border rounded-lg hover:shadow-md transition-shadow">
          <h4 class="font-semibold text-primary mb-2">#{escape_html(title)}</h4>
          <p class="text-sm text-gray-600">#{escape_html(description)}</p>
        </div>
        """
      end)

      """
      <div class="projects-section grid gap-4">
        #{projects_html}
      </div>
      """
    else
      """
      <div class="projects-section text-gray-500">
        <p>Projects will appear here once configured.</p>
      </div>
      """
    end
  end

  defp render_generic_content(content) do
    case content do
      %{"text" => text} when is_binary(text) ->
        """
        <div class="generic-section">
          <p>#{escape_html(text)}</p>
        </div>
        """

      %{"description" => description} when is_binary(description) ->
        """
        <div class="generic-section">
          <p>#{escape_html(description)}</p>
        </div>
        """

      content when is_map(content) and map_size(content) > 0 ->
        # Try to find any text content to display
        text_content = content
        |> Map.values()
        |> Enum.find(&is_binary/1)
        |> case do
          nil -> "Content available - check section configuration"
          text -> text
        end

        """
        <div class="generic-section">
          <p>#{escape_html(text_content)}</p>
        </div>
        """

      _ ->
        """
        <div class="generic-section text-gray-500">
          <p>No content configured for this section.</p>
        </div>
        """
    end
  end

  # ADD ADDITIONAL SECTION RENDERERS FOR COMPLETENESS:
  defp render_featured_project_content(content), do: render_projects_content(content)
  defp render_case_study_content(content), do: render_projects_content(content)
  defp render_achievements_content(content), do: render_generic_content(content)
  defp render_testimonial_content(content), do: render_generic_content(content)
  defp render_media_content(content), do: render_generic_content(content)
  defp render_contact_content(content), do: render_generic_content(content)

  # ADD HTML ESCAPING HELPER:
  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp escape_html(_), do: ""

  defp generate_preview_css(portfolio) do
    CssPriorityManager.generate_portfolio_css(portfolio, preview_mode: true)
  end

  defp load_portfolio_sections_enhanced(portfolio_id) do
    try do
      sections = Portfolios.list_portfolio_sections(portfolio_id)
      process_sections_for_display(sections)
    rescue
      error ->
        IO.puts("❌ Error loading sections: #{inspect(error)}")
        []
    end
  end

  defp build_customization_from_params(params, portfolio) do
    base_customization = portfolio.customization || %{}

    # Override with URL params if present
    url_customization = %{}

    url_customization = if primary = params["primary"] do
      Map.put(url_customization, "primary_color", "##{primary}")
    else
      url_customization
    end

    url_customization = if accent = params["accent"] do
      Map.put(url_customization, "accent_color", "##{accent}")
    else
      url_customization
    end

    url_customization = if layout = params["layout"] do
      Map.put(url_customization, "layout", layout)
    else
      url_customization
    end

    Map.merge(base_customization, url_customization)
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      sections = Portfolios.list_portfolio_sections(portfolio_id)

      # Ensure sections have proper data structure
      Enum.map(sections, fn section ->
        %{
          id: section.id,
          title: section.title || "Untitled Section",
          section_type: section.section_type,
          content: section.content || %{},
          position: section.position || 0,
          visible: section.visible
        }
      end)
      |> Enum.filter(& &1.visible)
      |> Enum.sort_by(& &1.position)
    rescue
      error ->
        IO.puts("❌ Error loading sections: #{inspect(error)}")
        []
    end
  end

  defp process_sections_for_display(sections) do
    sections
    |> Enum.map(fn section ->
      %{
        id: section.id,
        title: section.title || "Untitled Section",
        section_type: section.section_type,
        content: section.content || %{},
        position: section.position || 0,
        visible: section.visible
      }
    end)
    |> Enum.filter(& &1.visible)
    |> Enum.sort_by(& &1.position)
  end


end
