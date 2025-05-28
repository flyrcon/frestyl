# lib/frestyl/resume_exporter.ex
defmodule Frestyl.ResumeExporter do
  @moduledoc """
  Generates ATS-friendly PDF resumes from portfolio data
  """

  def generate_pdf(portfolio, owner) do
    try do
      resume_data = transform_portfolio_to_resume(portfolio, owner)
      html_content = render_ats_resume(resume_data)

      case ChromicPDF.print_to_pdf({:html, html_content}, pdf_options()) do
        {:ok, pdf_binary} -> {:ok, pdf_binary}
        {:error, reason} -> {:error, "PDF generation failed: #{inspect(reason)}"}
      end
    rescue
      e -> {:error, "Export error: #{Exception.message(e)}"}
    end
  end

  defp pdf_options do
    %{
      size: :a4,
      margin: %{top: 0.75, bottom: 0.75, left: 0.75, right: 0.75},
      print_background: false,
      scale: 1.0,
      prefer_css_page_size: false
    }
  end

  defp transform_portfolio_to_resume(portfolio, owner) do
    %{
      personal_info: extract_personal_info(owner, portfolio),
      summary: extract_summary(portfolio),
      experience: extract_experience(portfolio),
      projects: extract_projects(portfolio),
      skills: extract_skills(portfolio),
      education: extract_education(portfolio)
    }
  end

  defp extract_personal_info(owner, portfolio) do
    config = Map.get(portfolio, :resume_config, %{})

    %{
      name: Map.get(config, "name") || Map.get(owner, :full_name) || Map.get(owner, :name, ""),
      email: Map.get(config, "email") || Map.get(owner, :email, ""),
      phone: Map.get(config, "phone") || get_contact_info(portfolio, "phone"),
      location: Map.get(config, "location") || get_contact_info(portfolio, "location"),
      linkedin: Map.get(config, "linkedin") || get_contact_info(portfolio, "linkedin"),
      website: Map.get(config, "website") || get_contact_info(portfolio, "website") ||
               "#{System.get_env("APP_URL", "https://frestyl.com")}/p/#{Map.get(portfolio, :slug, "")}"
    }
  end

  defp get_contact_info(portfolio, field_name) do
    # Look for contact info in portfolio sections or content
    portfolio.sections
    |> Enum.find_value(fn section ->
      case Map.get(section, :section_type) do
        :contact -> Map.get(section.content || %{}, field_name)
        _ -> nil
      end
    end)
  end

  defp extract_summary(portfolio) do
    # Look for summary in portfolio description or dedicated summary section
    case Map.get(portfolio, :description) do
      desc when is_binary(desc) and byte_size(desc) > 0 -> desc
      _ ->
        portfolio.sections
        |> Enum.find_value(fn section ->
          case Map.get(section, :section_type) do
            :summary -> Map.get(section.content || %{}, "summary")
            _ -> nil
          end
        end)
    end
  end

  defp extract_experience(portfolio) do
    portfolio.sections
    |> Enum.filter(&(Map.get(&1, :section_type) == :experience))
    |> Enum.flat_map(fn section ->
      case Map.get(section.content || %{}, "jobs") do
        jobs when is_list(jobs) ->
          transform_jobs(jobs)
        _ -> []
      end
    end)
    |> Enum.sort_by(&parse_date(Map.get(&1, :start_date, "")), {:desc, Date})
  end

  defp transform_jobs(jobs) do
    Enum.map(jobs, fn job ->
      %{
        title: Map.get(job, "title", ""),
        company: Map.get(job, "company", ""),
        start_date: Map.get(job, "start_date", ""),
        end_date: if(Map.get(job, "current"), do: "Present", else: Map.get(job, "end_date", "")),
        description: Map.get(job, "description", ""),
        current: Map.get(job, "current", false)
      }
    end)
  end

  defp extract_projects(portfolio) do
    portfolio.sections
    |> Enum.filter(&(Map.get(&1, :section_type) in [:featured_project, :project, :case_study]))
    |> Enum.map(&transform_project/1)
    |> Enum.take(3)  # Limit to top 3 projects for ATS
  end

  defp transform_project(section) do
    content = Map.get(section, :content, %{})

    %{
      title: Map.get(content, "title") || Map.get(section, :title, ""),
      description: Map.get(content, "description") || Map.get(content, "summary", ""),
      technologies: Map.get(content, "technologies", []),
      demo_url: Map.get(content, "demo_url"),
      github_url: Map.get(content, "github_url"),
      timeline: Map.get(content, "timeline")
    }
  end

  defp extract_skills(portfolio) do
    portfolio.sections
    |> Enum.filter(&(Map.get(&1, :section_type) == :skills))
    |> Enum.flat_map(fn section ->
      Map.get(section.content || %{}, "skills", [])
    end)
    |> Enum.uniq()
    |> Enum.take(20)  # Limit for ATS readability
  end

  defp extract_education(portfolio) do
    portfolio.sections
    |> Enum.filter(&(Map.get(&1, :section_type) == :education))
    |> Enum.flat_map(fn section ->
      case Map.get(section.content || %{}, "education") do
        education when is_list(education) -> education
        _ -> []
      end
    end)
  end

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ ->
        # Try parsing MM/YYYY format
        case Regex.run(~r/(\d{1,2})\/(\d{4})/, date_string) do
          [_, month, year] ->
            Date.new!(String.to_integer(year), String.to_integer(month), 1)
          _ -> Date.utc_today()
        end
    end
  end
  defp parse_date(_), do: Date.utc_today()

  # ATS-Friendly HTML Template
  defp render_ats_resume(data) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{data.personal_info.name} - Resume</title>
      <style>#{ats_css()}</style>
    </head>
    <body>
      #{render_header(data.personal_info)}
      #{if data.summary, do: render_summary(data.summary), else: ""}
      #{if length(data.experience) > 0, do: render_experience(data.experience), else: ""}
      #{if length(data.projects) > 0, do: render_projects(data.projects), else: ""}
      #{if length(data.skills) > 0, do: render_skills(data.skills), else: ""}
      #{if length(data.education) > 0, do: render_education(data.education), else: ""}
    </body>
    </html>
    """
  end

  defp ats_css do
    """
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: Arial, sans-serif;
      font-size: 11pt;
      line-height: 1.4;
      color: #000000;
      max-width: 8.5in;
      margin: 0 auto;
      padding: 0.5in;
      background: white;
    }

    /* ATS-friendly headers */
    h1 {
      font-size: 18pt;
      font-weight: bold;
      margin-bottom: 0.2in;
      text-align: center;
      color: #000000;
    }

    h2 {
      font-size: 12pt;
      font-weight: bold;
      margin: 0.25in 0 0.1in 0;
      text-transform: uppercase;
      color: #000000;
      border-bottom: 1px solid #000000;
      padding-bottom: 2pt;
    }

    h3 {
      font-size: 11pt;
      font-weight: bold;
      margin: 0.15in 0 0.05in 0;
      color: #000000;
    }

    /* Contact info */
    .contact-info {
      text-align: center;
      margin-bottom: 0.25in;
      font-size: 10pt;
    }

    .contact-info div {
      margin: 2pt 0;
    }

    /* Job entries */
    .job-entry {
      margin-bottom: 0.2in;
      page-break-inside: avoid;
    }

    .job-header {
      margin-bottom: 0.05in;
    }

    .job-title {
      font-weight: bold;
      display: inline;
    }

    .company {
      display: inline;
      margin-left: 0.2in;
    }

    .date-range {
      float: right;
      font-size: 10pt;
    }

    .job-description {
      margin-top: 0.05in;
      text-align: justify;
      clear: both;
    }

    /* Projects */
    .project-entry {
      margin-bottom: 0.15in;
      page-break-inside: avoid;
    }

    .project-title {
      font-weight: bold;
    }

    .project-links {
      font-size: 10pt;
      margin-top: 0.05in;
    }

    /* Skills */
    .skills-list {
      text-align: justify;
      line-height: 1.6;
    }

    /* Education */
    .education-entry {
      margin-bottom: 0.15in;
      page-break-inside: avoid;
    }

    /* Lists */
    ul {
      margin-left: 0.25in;
      margin-bottom: 0.1in;
    }

    li {
      margin-bottom: 0.05in;
    }

    /* Ensure no page breaks in critical sections */
    .no-break {
      page-break-inside: avoid;
    }

    /* Remove any decorative elements that ATS might not parse */
    .hide-from-ats {
      display: none;
    }
    """
  end

  defp render_header(personal_info) do
    """
    <div class="header no-break">
      <h1>#{personal_info.name}</h1>
      <div class="contact-info">
        #{if personal_info.email && personal_info.email != "", do: "<div>#{personal_info.email}</div>", else: ""}
        #{if personal_info.phone && personal_info.phone != "", do: "<div>#{personal_info.phone}</div>", else: ""}
        #{if personal_info.location && personal_info.location != "", do: "<div>#{personal_info.location}</div>", else: ""}
        #{if personal_info.linkedin && personal_info.linkedin != "", do: "<div>#{personal_info.linkedin}</div>", else: ""}
        #{if personal_info.website && personal_info.website != "", do: "<div>#{personal_info.website}</div>", else: ""}
      </div>
    </div>
    """
  end

  defp render_summary(summary) do
    """
    <div class="section no-break">
      <h2>Professional Summary</h2>
      <p>#{summary}</p>
    </div>
    """
  end

  defp render_experience(experiences) do
    experience_html = Enum.map(experiences, &render_job/1) |> Enum.join("\n")

    """
    <div class="section">
      <h2>Professional Experience</h2>
      #{experience_html}
    </div>
    """
  end

  defp render_job(job) do
    """
    <div class="job-entry">
      <div class="job-header">
        <span class="job-title">#{Map.get(job, :title, "")}</span>
        <span class="company">#{Map.get(job, :company, "")}</span>
        <span class="date-range">#{format_date_range(job)}</span>
      </div>
      #{if Map.get(job, :description) && String.length(Map.get(job, :description, "")) > 0, do: "<div class=\"job-description\">#{Map.get(job, :description)}</div>", else: ""}
    </div>
    """
  end

  defp format_date_range(job) do
    start_date = Map.get(job, :start_date, "")
    end_date = Map.get(job, :end_date, "")

    case {start_date, end_date} do
      {"", ""} -> ""
      {start, ""} -> start
      {"", end_d} -> end_d
      {start, end_d} -> "#{start} - #{end_d}"
    end
  end

  defp render_projects(projects) do
    projects_html = Enum.map(projects, &render_project/1) |> Enum.join("\n")

    """
    <div class="section">
      <h2>Featured Projects</h2>
      #{projects_html}
    </div>
    """
  end

  defp render_project(project) do
    """
    <div class="project-entry">
      <div class="project-title">#{Map.get(project, :title, "")}</div>
      #{if Map.get(project, :description) && String.length(Map.get(project, :description, "")) > 0, do: "<div>#{Map.get(project, :description)}</div>", else: ""}
      #{if length(Map.get(project, :technologies, [])) > 0, do: "<div><strong>Technologies:</strong> #{Enum.join(Map.get(project, :technologies), ", ")}</div>", else: ""}
      <div class="project-links">
        #{render_project_links(project)}
      </div>
    </div>
    """
  end

  defp render_project_links(project) do
    links = []

    links = if Map.get(project, :demo_url) && Map.get(project, :demo_url) != "" do
      ["Demo: #{Map.get(project, :demo_url)}" | links]
    else
      links
    end

    links = if Map.get(project, :github_url) && Map.get(project, :github_url) != "" do
      ["Code: #{Map.get(project, :github_url)}" | links]
    else
      links
    end

    Enum.join(Enum.reverse(links), " | ")
  end

  defp render_skills(skills) do
    skills_text = Enum.join(skills, " • ")

    """
    <div class="section">
      <h2>Technical Skills</h2>
      <div class="skills-list">#{skills_text}</div>
    </div>
    """
  end

  defp render_education(education) do
    education_html = Enum.map(education, &render_education_item/1) |> Enum.join("\n")

    """
    <div class="section">
      <h2>Education</h2>
      #{education_html}
    </div>
    """
  end

  defp render_education_item(item) do
    """
    <div class="education-entry">
      <strong>#{Map.get(item, "degree", "")} #{Map.get(item, "field", "")}</strong><br>
      #{Map.get(item, "institution", "")} | #{Map.get(item, "year", "")}
    </div>
    """
  end
end
