# lib/frestyl_web/live/portfolio_live/live_preview.ex
# COMPLETE VERSION WITH ALL FUNCTIONS

defmodule FrestylWeb.PortfolioLive.LivePreview do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => portfolio_id, "preview_token" => token}, _session, socket) do
    IO.puts("🔥 LIVE PREVIEW MOUNT: portfolio_id=#{portfolio_id}")

    if verify_preview_token(portfolio_id, token) do
      portfolio = Portfolios.get_portfolio!(portfolio_id)
      IO.puts("🔥 PORTFOLIO LOADED: #{portfolio.title}")

      # Subscribe to live preview updates
      PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")

      sections = load_portfolio_sections(portfolio.id)
      IO.puts("🔥 SECTIONS LOADED: #{length(sections)} sections")

      socket =
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:preview_mode, true)
        |> assign(:mobile_view, false)
        |> assign(:viewport_width, "100%")
        |> assign(:customization, portfolio.customization || %{})
        |> assign(:preview_css, generate_preview_css(portfolio))
        |> assign(:sections, sections)

      {:ok, socket}
    else
      {:ok, socket |> put_flash(:error, "Invalid preview session") |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_info({:preview_update, customization, css}, socket) do
    socket =
      socket
      |> assign(:customization, customization)
      |> assign(:preview_css, css)
      |> push_event("update_preview_styles", %{css: css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:viewport_change, mobile_view}, socket) do
    viewport_width = if mobile_view, do: "375px", else: "100%"

    socket =
      socket
      |> assign(:mobile_view, mobile_view)
      |> assign(:viewport_width, viewport_width)

    {:noreply, socket}
  end

  defp verify_preview_token(portfolio_id, token) do
    expected_token = :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
                     |> Base.encode16(case: :lower)

    token == expected_token
  end

  defp generate_preview_css(portfolio) do
    generate_portfolio_css(portfolio.customization || %{}, portfolio.theme || "minimal")
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp generate_portfolio_css(customization, theme) do
    primary_color = Map.get(customization, "primary_color", "#374151")
    accent_color = Map.get(customization, "accent_color", "#059669")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    layout = Map.get(customization, "layout", "minimal")

    base_css = get_theme_css(theme)
    custom_css = """
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
      --secondary-color: #{secondary_color};
    }

    .portfolio-container {
      background: var(--primary-color);
      color: #ffffff;
    }

    .section {
      margin-bottom: 2rem;
      padding: 1.5rem;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.1);
    }

    .accent {
      color: var(--accent-color);
    }

    .layout-#{layout} .section {
      #{get_layout_specific_css(layout)}
    }

    * {
      transition: background-color 0.3s ease,
                  color 0.3s ease,
                  border-color 0.3s ease;
    }

    @media (max-width: 768px) {
      .portfolio-container {
        padding: 1rem;
      }
      .section {
        margin-bottom: 1rem;
        padding: 1rem;
      }
    }
    """

    base_css <> custom_css
  end

  defp get_theme_css("minimal") do
    """
    body {
      font-family: 'Inter', sans-serif;
      line-height: 1.6;
      margin: 0;
      padding: 0;
    }
    .portfolio-container {
      min-height: 100vh;
      padding: 2rem;
    }
    """
  end

  defp get_theme_css("professional") do
    """
    body {
      font-family: 'Merriweather', serif;
      line-height: 1.8;
      margin: 0;
      padding: 0;
    }
    .portfolio-container {
      min-height: 100vh;
      padding: 3rem;
      max-width: 1200px;
      margin: 0 auto;
    }
    """
  end

  defp get_theme_css("creative") do
    """
    body {
      font-family: 'Poppins', sans-serif;
      line-height: 1.5;
      margin: 0;
      padding: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    .portfolio-container {
      min-height: 100vh;
      padding: 2rem;
    }
    """
  end

  defp get_theme_css(_), do: get_theme_css("minimal")

  defp get_layout_specific_css("dashboard") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem;"
  end

  defp get_layout_specific_css("gallery") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 0.5rem;"
  end

  defp get_layout_specific_css(_), do: ""

  # MAIN CONTENT RENDERING FUNCTION
  def render_section_content(section) do
    content = section.content || %{}
    section_type = normalize_section_type(section.section_type)

    case section_type do
      :intro -> render_intro_content(content)
      :experience -> render_experience_content(content)
      :education -> render_education_content(content)
      :skills -> render_skills_content(content)
      :projects -> render_projects_content(content)
      :featured_project -> render_featured_project_content(content)
      :achievements -> render_achievements_content(content)
      :case_study -> render_case_study_content(content)
      :testimonial -> render_testimonial_content(content)
      :contact -> render_contact_content(content)
      :media_showcase -> render_media_showcase_content(content)
      :story -> render_story_content(content)
      :journey -> render_journey_content(content)
      :narrative -> render_narrative_content(content)
      :custom -> render_custom_content(content)
      _ -> render_generic_content(content)
    end
  end

  # INDIVIDUAL CONTENT RENDERERS
  defp render_intro_content(content) do
    headline = safe_extract(content, ["headline", "title"])
    summary = safe_extract(content, ["summary", "description", "bio"])
    location = safe_extract(content, ["location"])

    parts = []
    parts = if headline != "", do: parts ++ ["<h3 class=\"text-lg font-semibold mb-2\">#{Phoenix.HTML.html_escape(headline)}</h3>"], else: parts
    parts = if summary != "", do: parts ++ ["<p class=\"mb-3\">#{Phoenix.HTML.html_escape(summary)}</p>"], else: parts
    parts = if location != "", do: parts ++ ["<p class=\"text-sm\"><span class=\"mr-1\">📍</span>#{Phoenix.HTML.html_escape(location)}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Introduction content...</p>")
    end
  end

  defp render_experience_content(content) do
    jobs = safe_extract_list(content, ["jobs", "experiences"])

    if length(jobs) > 0 do
      job_html = Enum.map(jobs, fn job ->
        title = safe_extract_from_map(job, ["title", "position"])
        company = safe_extract_from_map(job, ["company", "organization"])
        start_date = safe_extract_from_map(job, ["start_date"])
        end_date = safe_extract_from_map(job, ["end_date"], "Present")
        description = safe_extract_from_map(job, ["description", "summary"])

        """
        <div class="mb-4 pb-4 border-b border-gray-200 last:border-b-0">
          <div class="font-semibold">#{Phoenix.HTML.html_escape(title)}</div>
          <div class="text-sm text-gray-600">#{Phoenix.HTML.html_escape(company)}</div>
          <div class="text-xs text-gray-500 mb-2">#{Phoenix.HTML.html_escape(start_date)} - #{Phoenix.HTML.html_escape(end_date)}</div>
          #{if description != "", do: "<p class=\"text-sm\">#{Phoenix.HTML.html_escape(description)}</p>", else: ""}
        </div>
        """
      end) |> Enum.join("")

      Phoenix.HTML.raw(job_html)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Experience details...</p>")
    end
  end

  defp render_education_content(content) do
    education = safe_extract_list(content, ["education", "degrees"])

    if length(education) > 0 do
      edu_html = Enum.map(education, fn edu ->
        degree = safe_extract_from_map(edu, ["degree", "title"])
        school = safe_extract_from_map(edu, ["school", "institution"])
        year = safe_extract_from_map(edu, ["year", "graduation_year"])

        """
        <div class="mb-3">
          <div class="font-semibold">#{Phoenix.HTML.html_escape(degree)}</div>
          <div class="text-sm text-gray-600">#{Phoenix.HTML.html_escape(school)}</div>
          #{if year != "", do: "<div class=\"text-xs text-gray-500\">#{Phoenix.HTML.html_escape(year)}</div>", else: ""}
        </div>
        """
      end) |> Enum.join("")

      Phoenix.HTML.raw(edu_html)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Education details...</p>")
    end
  end

  defp render_skills_content(content) do
    skills = safe_extract_list(content, ["skills"])

    if length(skills) > 0 do
      skills_html = Enum.map(skills, fn skill ->
        skill_name = if is_binary(skill), do: skill, else: to_string(skill)
        "<span class=\"inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded mr-2 mb-2\">#{Phoenix.HTML.html_escape(skill_name)}</span>"
      end) |> Enum.join("")

      Phoenix.HTML.raw("<div class=\"flex flex-wrap\">#{skills_html}</div>")
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Skills list...</p>")
    end
  end

  defp render_projects_content(content) do
    projects = safe_extract_list(content, ["projects"])

    if length(projects) > 0 do
      projects_html = Enum.take(projects, 2) |> Enum.map(fn project ->
        title = safe_extract_from_map(project, ["title", "name"])
        description = safe_extract_from_map(project, ["description", "summary"])

        """
        <div class="mb-3 pb-3 border-b border-gray-200 last:border-b-0">
          <div class="font-semibold">#{Phoenix.HTML.html_escape(title)}</div>
          #{if description != "", do: "<p class=\"text-sm text-gray-600\">#{Phoenix.HTML.html_escape(String.slice(description, 0, 100))}#{if String.length(description) > 100, do: "...", else: ""}</p>", else: ""}
        </div>
        """
      end) |> Enum.join("")

      more_text = if length(projects) > 2, do: "<p class=\"text-xs text-gray-500\">...and #{length(projects) - 2} more projects</p>", else: ""

      Phoenix.HTML.raw(projects_html <> more_text)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Project showcase...</p>")
    end
  end

  defp render_featured_project_content(content) do
    title = safe_extract(content, ["title", "name"])
    description = safe_extract(content, ["description", "summary"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if description != "", do: parts ++ ["<p class=\"text-sm mb-3\">#{Phoenix.HTML.html_escape(description)}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Featured project details...</p>")
    end
  end

  defp render_achievements_content(content) do
    achievements = safe_extract_list(content, ["achievements", "awards"])

    if length(achievements) > 0 do
      achievements_html = Enum.take(achievements, 3) |> Enum.map(fn achievement ->
        title = if is_binary(achievement), do: achievement, else: to_string(achievement)
        "<div class=\"flex items-center mb-2\"><span class=\"mr-2\">🏆</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(title)}</span></div>"
      end) |> Enum.join("")

      Phoenix.HTML.raw(achievements_html)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Achievements and awards...</p>")
    end
  end

  defp render_case_study_content(content) do
    title = safe_extract(content, ["title"])
    overview = safe_extract(content, ["overview", "summary"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if overview != "", do: parts ++ ["<p class=\"text-sm mb-2\">#{Phoenix.HTML.html_escape(String.slice(overview, 0, 150))}#{if String.length(overview) > 150, do: "...", else: ""}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Case study details...</p>")
    end
  end

  defp render_testimonial_content(content) do
    testimonials = safe_extract_list(content, ["testimonials"])

    if length(testimonials) > 0 do
      testimonial = List.first(testimonials)
      quote = safe_extract_from_map(testimonial, ["quote", "text"])
      author = safe_extract_from_map(testimonial, ["author", "name"])

      if quote != "" do
        Phoenix.HTML.raw("""
        <blockquote class="italic text-gray-600 border-l-4 border-blue-500 pl-4">
          "#{Phoenix.HTML.html_escape(String.slice(quote, 0, 120))}#{if String.length(quote) > 120, do: "...", else: ""}"
          #{if author != "", do: "<cite class=\"block text-sm text-gray-500 mt-2\">— #{Phoenix.HTML.html_escape(author)}</cite>", else: ""}
        </blockquote>
        """)
      else
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Client testimonial...</p>")
      end
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Client testimonials...</p>")
    end
  end

  defp render_contact_content(content) do
    email = safe_extract(content, ["email"])
    phone = safe_extract(content, ["phone"])
    location = safe_extract(content, ["location"])

    parts = []
    parts = if email != "", do: parts ++ ["<div class=\"flex items-center mb-2\"><span class=\"mr-2\">📧</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(email)}</span></div>"], else: parts
    parts = if phone != "", do: parts ++ ["<div class=\"flex items-center mb-2\"><span class=\"mr-2\">📞</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(phone)}</span></div>"], else: parts
    parts = if location != "", do: parts ++ ["<div class=\"flex items-center mb-2\"><span class=\"mr-2\">📍</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(location)}</span></div>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Contact information...</p>")
    end
  end

  defp render_media_showcase_content(content) do
    # SAFE VERSION - no content extraction
    html = """
    <div class="flex items-center space-x-2">
      <span class="text-2xl">🎬</span>
      <div>
        <p class="font-semibold">Video Introduction</p>
        <p class="text-sm text-gray-600">Media content available</p>
      </div>
    </div>
    """

    Phoenix.HTML.raw(html)
  end

  defp render_story_content(content) do
    title = safe_extract(content, ["title"])
    narrative = safe_extract(content, ["narrative"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if narrative != "", do: parts ++ ["<p class=\"text-sm\">#{Phoenix.HTML.html_escape(String.slice(narrative, 0, 200))}#{if String.length(narrative) > 200, do: "...", else: ""}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Story content...</p>")
    end
  end

  defp render_journey_content(content) do
    title = safe_extract(content, ["title"])
    introduction = safe_extract(content, ["introduction"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if introduction != "", do: parts ++ ["<p class=\"text-sm\">#{Phoenix.HTML.html_escape(String.slice(introduction, 0, 150))}#{if String.length(introduction) > 150, do: "...", else: ""}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Journey content...</p>")
    end
  end

  defp render_narrative_content(content) do
    title = safe_extract(content, ["title"])
    subtitle = safe_extract(content, ["subtitle"])
    narrative = safe_extract(content, ["narrative"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if subtitle != "", do: parts ++ ["<p class=\"text-sm text-gray-600 mb-2\">#{Phoenix.HTML.html_escape(subtitle)}</p>"], else: parts
    parts = if narrative != "", do: parts ++ ["<p class=\"text-sm\">#{Phoenix.HTML.html_escape(String.slice(narrative, 0, 180))}#{if String.length(narrative) > 180, do: "...", else: ""}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Narrative content...</p>")
    end
  end

  defp render_custom_content(content) do
    title = safe_extract(content, ["title"])
    content_text = safe_extract(content, ["content", "main_content"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if content_text != "", do: parts ++ ["<p class=\"text-sm\">#{Phoenix.HTML.html_escape(String.slice(content_text, 0, 150))}#{if String.length(content_text) > 150, do: "...", else: ""}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Custom content...</p>")
    end
  end

  defp render_generic_content(content) do
    description = safe_extract(content, ["description", "summary", "content", "text", "main_content"])

    if description != "" do
      Phoenix.HTML.raw("<p class=\"text-sm\">#{Phoenix.HTML.html_escape(String.slice(description, 0, 200))}#{if String.length(description) > 200, do: "...", else: ""}</p>")
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Section content...</p>")
    end
  end

  defp safe_extract(content, keys) when is_list(keys) do
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

  # Map extraction function
  defp safe_extract_from_map(map, keys, default \\ "") when is_map(map) and is_list(keys) do
    Enum.find_value(keys, default, fn key ->
      case Map.get(map, key) do
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

  # List extraction function
  defp safe_extract_list(content, keys) when is_list(keys) do
    Enum.find_value(keys, [], fn key ->
      case Map.get(content, key) do
        nil -> nil
        list when is_list(list) -> list
        _ -> nil
      end
    end)
  end

  defp convert_to_safe_string(value) do
    case value do
      nil ->
        nil
      "" ->
        nil
      {:safe, safe_value} ->
        # Handle Phoenix.HTML.safe tuple more robustly
        case safe_value do
          list when is_list(list) ->
            try do
              list |> Enum.join("") |> String.trim()
            rescue
              _ ->
                list |> inspect() |> String.trim()
            end
          binary when is_binary(binary) ->
            String.trim(binary)
          other ->
            try do
              other |> to_string() |> String.trim()
            rescue
              _ ->
                other |> inspect() |> String.trim()
            end
        end
      value when is_binary(value) ->
        String.trim(value)
      value when is_atom(value) ->
        Atom.to_string(value)
      value when is_number(value) ->
        to_string(value)
      value ->
        try do
          to_string(value)
        rescue
          _ ->
            inspect(value)
        end
    end
    |> case do
      nil -> nil
      "" -> nil
      result when is_binary(result) ->
        trimmed = String.trim(result)
        if trimmed == "", do: nil, else: trimmed
      _ -> nil
    end
  end

  defp safe_extract_debug(content, keys) when is_list(keys) do
  Enum.find_value(keys, "", fn key ->
    value = Map.get(content, key)
    IO.puts("🔥 DEBUG safe_extract key='#{key}' value=#{inspect(value)}")

    result = case value do
      nil -> nil
      "" -> nil
      {:safe, safe_value} ->
        IO.puts("🔥 Found safe tuple with value: #{inspect(safe_value)}")
        # Force convert to string without using to_string
        cond do
          is_binary(safe_value) -> String.trim(safe_value)
          is_list(safe_value) -> Enum.join(safe_value, "") |> String.trim()
          true -> "#{safe_value}" |> String.trim()  # Force string interpolation
        end
      value when is_binary(value) -> String.trim(value)
      _ -> "#{value}"  # Force string interpolation
    end

    IO.puts("🔥 DEBUG result: #{inspect(result)}")
    if result == "", do: nil, else: result
  end)
end


  defp normalize_section_type(type) when is_atom(type), do: type
  defp normalize_section_type(type) when is_binary(type), do: String.to_atom(type)
  defp normalize_section_type(_), do: :generic
end
