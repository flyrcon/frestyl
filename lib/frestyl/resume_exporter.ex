# lib/frestyl/resume_exporter.ex
defmodule Frestyl.ResumeExporter do
  @moduledoc """
  Export engine for generating portfolios in various formats using ChromicPDF.
  Supports ATS-optimized PDFs, full portfolios, HTML archives, and DOCX files.
  """

  require Logger
  alias Frestyl.Portfolios
  alias Frestyl.Storage.TempFileManager

  # Export formats and their configurations
  @export_formats %{
    ats_resume: %{
      template: "ats_resume.html.heex",
      output_type: :pdf,
      page_size: :letter,
      margins: %{top: "0.5in", bottom: "0.5in", left: "0.5in", right: "0.5in"}
    },
    full_portfolio: %{
      template: "full_portfolio.html.heex",
      output_type: :pdf,
      page_size: :letter,
      margins: %{top: "0.75in", bottom: "0.75in", left: "0.75in", right: "0.75in"}
    },
    html_archive: %{
      template: "html_archive.html.heex",
      output_type: :html,
      standalone: true
    },
    docx_resume: %{
      template: "docx_template.html",
      output_type: :docx,
      convert_via: :pandoc
    }
  }

  @doc """
  Main export function. Generates portfolio in specified format.
  """
  def export_portfolio(portfolio, format, options \\ %{}) do
    Logger.info("Starting export: portfolio_id=#{portfolio.id}, format=#{format}")

    with {:ok, format_config} <- validate_export_format(format),
         {:ok, export_data} <- prepare_export_data(portfolio, format, options),
         {:ok, file_info} <- generate_export_file(export_data, format_config) do

      Logger.info("Export completed successfully: #{file_info.filename}")
      {:ok, file_info}
    else
      {:error, reason} ->
        Logger.error("Export failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Export specifically optimized for ATS (Applicant Tracking Systems)
  """
  def export_ats_resume(portfolio, options \\ %{}) do
    ats_options =
      Map.merge(%{
        "font_family" => "Arial",
        "font_size" => "11pt",
        "include_photo" => false,
        "sections" => ["contact", "summary", "experience", "education", "skills"],
        "optimize_for_ats" => true
      }, options)

    export_portfolio(portfolio, :ats_resume, ats_options)
  end

  @doc """
  Export complete portfolio with all sections and media
  """
  def export_full_portfolio(portfolio, options \\ %{}) do
    full_options =
      Map.merge(%{
        "include_photo" => true,
        "include_projects" => true,
        "include_testimonials" => true,
        "include_media" => true,
        "page_orientation" => "portrait"
      }, options)

    export_portfolio(portfolio, :full_portfolio, full_options)
  end

  @doc """
  Export self-contained HTML archive
  """
  def export_html_archive(portfolio, options \\ %{}) do
    html_options =
      Map.merge(%{
        "responsive_design" => true,
        "include_print_styles" => true,
        "embed_assets" => true,
        "include_navigation" => true
      }, options)

    export_portfolio(portfolio, :html_archive, html_options)
  end

  @doc """
  Export DOCX resume (portfolio owner only)
  """
  def export_docx_resume(portfolio, current_user, options \\ %{}) do
    if portfolio.user_id == current_user.id do
      docx_options =
        Map.merge(%{
          "template_style" => "professional",
          "include_photo" => false,
          "editable_fields" => true
        }, options)

      export_portfolio(portfolio, :docx_resume, docx_options)
    else
      {:error, "Access denied: DOCX export is only available to portfolio owners"}
    end
  end

  # Private Functions

  defp validate_export_format(format) do
    case Map.get(@export_formats, format) do
      nil -> {:error, "Unsupported export format: #{format}"}
      config -> {:ok, config}
    end
  end

  defp prepare_export_data(portfolio, format, options) do
    try do
      export_data = %{
        portfolio: portfolio,
        format: format,
        options: options,
        timestamp: DateTime.utc_now(),
        sections: extract_portfolio_sections(portfolio, options),
        metadata: generate_export_metadata(portfolio, format, options)
      }

      {:ok, export_data}
    rescue
      e ->
        {:error, "Failed to prepare export data: #{Exception.message(e)}"}
    end
  end

  defp extract_portfolio_sections(portfolio, options) do
    available_sections = %{
      contact: extract_contact_section(portfolio),
      summary: extract_summary_section(portfolio),
      experience: extract_experience_section(portfolio),
      education: extract_education_section(portfolio),
      skills: extract_skills_section(portfolio),
      projects: extract_projects_section(portfolio),
      certifications: extract_certifications_section(portfolio),
      testimonials: extract_testimonials_section(portfolio)
    }

    # Filter sections based on options
    requested_sections = Map.get(options, "sections", Map.keys(available_sections))

    available_sections
    |> Enum.filter(fn {key, _} -> Atom.to_string(key) in requested_sections end)
    |> Enum.into(%{})
  end

  defp generate_export_metadata(portfolio, format, options) do
    %{
      title: portfolio.title || "Portfolio Export",
      author: get_portfolio_owner_name(portfolio),
      subject: "Portfolio Export - #{format}",
      creator: "Frestyl Portfolio System",
      creation_date: DateTime.utc_now(),
      format: format,
      options: options
    }
  end

  defp generate_export_file(export_data, format_config) do
    case format_config.output_type do
      :pdf -> generate_pdf_export(export_data, format_config)
      :html -> generate_html_export(export_data, format_config)
      :docx -> generate_docx_export(export_data, format_config)
    end
  end

  # PDF Generation using ChromicPDF
  defp generate_pdf_export(export_data, format_config) do
    try do
      # Render HTML template
      html_content = render_export_template(export_data, format_config)

      # Generate PDF using ChromicPDF
      pdf_options = build_chromic_pdf_options(export_data, format_config)

      case ChromicPDF.print_to_pdf({:html, html_content}, pdf_options) do
        {:ok, pdf_binary} ->
          save_export_file(pdf_binary, export_data, "pdf")

        {:error, reason} ->
          {:error, "PDF generation failed: #{reason}"}
      end
    rescue
      e ->
        {:error, "PDF export error: #{Exception.message(e)}"}
    end
  end

  # HTML Generation
  defp generate_html_export(export_data, format_config) do
    try do
      html_content = render_export_template(export_data, format_config)

      # For HTML archives, embed all assets inline
      if export_data.options["embed_assets"] do
        html_content = embed_html_assets(html_content)
      end

      save_export_file(html_content, export_data, "html")
    rescue
      e ->
        {:error, "HTML export error: #{Exception.message(e)}"}
    end
  end

  # DOCX Generation using Pandoc
  defp generate_docx_export(export_data, format_config) do
    try do
      # First generate HTML
      html_content = render_export_template(export_data, format_config)

      # Create temporary HTML file for pandoc
      temp_html_path = Path.join(System.tmp_dir!(), "portfolio_#{:rand.uniform(10000)}.html")
      File.write!(temp_html_path, html_content)

      # Convert to DOCX using pandoc
      temp_docx_path = Path.join(System.tmp_dir!(), "portfolio_#{:rand.uniform(10000)}.docx")

      case System.cmd("pandoc", [
        temp_html_path,
        "-o", temp_docx_path,
        "--reference-doc", get_docx_template_path(export_data.options["template_style"])
      ]) do
        {_, 0} ->
          docx_binary = File.read!(temp_docx_path)

          # Cleanup temp files
          File.rm(temp_html_path)
          File.rm(temp_docx_path)

          save_export_file(docx_binary, export_data, "docx")

        {error, _} ->
          # Cleanup on error
          File.rm(temp_html_path)
          if File.exists?(temp_docx_path), do: File.rm(temp_docx_path)

          {:error, "DOCX conversion failed: #{error}"}
      end
    rescue
      e ->
        {:error, "DOCX export error: #{Exception.message(e)}"}
    end
  end

  defp build_chromic_pdf_options(export_data, format_config) do
    base_options = [
      size: format_config.page_size,
      margin_top: format_config.margins.top,
      margin_bottom: format_config.margins.bottom,
      margin_left: format_config.margins.left,
      margin_right: format_config.margins.right,
      print_background: true,
      prefer_css_page_size: true
    ]

    # Add metadata
    metadata_options = [
      info: %{
        title: export_data.metadata.title,
        author: export_data.metadata.author,
        subject: export_data.metadata.subject,
        creator: export_data.metadata.creator
      }
    ]

    # Add format-specific options
    format_specific_options =
      case export_data.format do
        :ats_resume ->
          [
            # ATS-optimized settings
            disable_scripts: true,
            disable_plugins: true
          ]

        :full_portfolio ->
          [
            # Full portfolio may include more complex layouts
            wait_for: "networkidle",
            timeout: 30_000
          ]

        _ ->
          []
      end

    base_options ++ metadata_options ++ format_specific_options
  end

  defp render_export_template(export_data, format_config) do
    template_path = Path.join([
      :code.priv_dir(:frestyl),
      "templates",
      "exports",
      format_config.template
    ])

    case format_config.template do
      "ats_resume.html.heex" ->
        render_ats_template(export_data)

      "full_portfolio.html.heex" ->
        render_full_portfolio_template(export_data)

      "html_archive.html.heex" ->
        render_html_archive_template(export_data)

      "docx_template.html" ->
        render_docx_template(export_data)

      _ ->
        raise "Unknown template: #{format_config.template}"
    end
  end

  defp render_ats_template(export_data) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{export_data.metadata.title}</title>
        <style>
            #{generate_ats_css(export_data.options)}
        </style>
    </head>
    <body>
        <div class="resume-container">
            #{render_ats_header(export_data.sections.contact)}
            #{render_ats_summary(export_data.sections.summary)}
            #{render_ats_experience(export_data.sections.experience)}
            #{render_ats_education(export_data.sections.education)}
            #{render_ats_skills(export_data.sections.skills)}
        </div>
    </body>
    </html>
    """
  end

  defp render_full_portfolio_template(export_data) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{export_data.metadata.title}</title>
        <style>
            #{generate_portfolio_css(export_data.options)}
        </style>
    </head>
    <body>
        <div class="portfolio-container">
            #{render_portfolio_header(export_data)}
            #{render_portfolio_sections(export_data.sections)}
        </div>
    </body>
    </html>
    """
  end

  defp render_html_archive_template(export_data) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{export_data.metadata.title}</title>
        <style>
            #{generate_responsive_css(export_data.options)}
            #{if export_data.options["include_print_styles"], do: generate_print_css(), else: ""}
        </style>
    </head>
    <body>
        <div class="archive-container">
            #{if export_data.options["include_navigation"], do: render_navigation(export_data.sections), else: ""}
            #{render_archive_content(export_data)}
        </div>
    </body>
    </html>
    """
  end

  defp render_docx_template(export_data) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            #{generate_docx_css(export_data.options)}
        </style>
    </head>
    <body>
        <div class="docx-container">
            #{render_docx_content(export_data)}
        </div>
    </body>
    </html>
    """
  end

  # CSS Generation Functions
  defp generate_ats_css(options) do
    font_family = Map.get(options, "font_family", "Arial")
    font_size = Map.get(options, "font_size", "11pt")

    """
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: '#{font_family}', sans-serif;
        font-size: #{font_size};
        line-height: 1.4;
        color: #000;
        background: white;
    }

    .resume-container {
        max-width: 8.5in;
        margin: 0 auto;
        padding: 0.5in;
    }

    .header {
        text-align: center;
        margin-bottom: 0.25in;
        border-bottom: 1px solid #000;
        padding-bottom: 0.15in;
    }

    .name {
        font-size: 18pt;
        font-weight: bold;
        margin-bottom: 5pt;
    }

    .contact-info {
        font-size: 10pt;
        line-height: 1.2;
    }

    .section {
        margin-bottom: 0.2in;
    }

    .section-title {
        font-size: 12pt;
        font-weight: bold;
        text-transform: uppercase;
        border-bottom: 1px solid #000;
        margin-bottom: 8pt;
        padding-bottom: 2pt;
    }

    .job-entry {
        margin-bottom: 12pt;
    }

    .job-title {
        font-weight: bold;
        font-size: 11pt;
    }

    .company {
        font-weight: bold;
        margin-bottom: 2pt;
    }

    .dates {
        font-style: italic;
        font-size: 10pt;
        margin-bottom: 4pt;
    }

    .description {
        margin-left: 0.15in;
    }

    .skills-list {
        line-height: 1.3;
    }

    @media print {
        body {
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }

        .resume-container {
            margin: 0;
            padding: 0.5in;
        }
    }
    """
  end

  defp generate_portfolio_css(options) do
    """
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: 'Helvetica', 'Arial', sans-serif;
        font-size: 12pt;
        line-height: 1.5;
        color: #333;
        background: white;
    }

    .portfolio-container {
        max-width: 8.5in;
        margin: 0 auto;
        padding: 0.75in;
    }

    .portfolio-header {
        text-align: center;
        margin-bottom: 0.5in;
        border-bottom: 2px solid #0066cc;
        padding-bottom: 0.25in;
    }

    .portfolio-title {
        font-size: 24pt;
        font-weight: bold;
        color: #0066cc;
        margin-bottom: 10pt;
    }

    .section {
        margin-bottom: 0.35in;
        page-break-inside: avoid;
    }

    .section-title {
        font-size: 16pt;
        font-weight: bold;
        color: #0066cc;
        border-bottom: 1px solid #0066cc;
        margin-bottom: 15pt;
        padding-bottom: 5pt;
    }

    .project-card {
        border: 1px solid #ddd;
        border-radius: 8px;
        padding: 15pt;
        margin-bottom: 15pt;
        background: #f9f9f9;
    }

    .project-title {
        font-size: 14pt;
        font-weight: bold;
        margin-bottom: 8pt;
    }

    @media print {
        .portfolio-container {
            margin: 0;
            padding: 0.75in;
        }

        .page-break {
            page-break-before: always;
        }
    }
    """
  end

  defp generate_responsive_css(options) do
    """
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: system-ui, -apple-system, sans-serif;
        line-height: 1.6;
        color: #333;
        background: #f5f5f5;
    }

    .archive-container {
        max-width: 1200px;
        margin: 0 auto;
        background: white;
        min-height: 100vh;
    }

    .navigation {
        background: #0066cc;
        color: white;
        padding: 1rem;
        position: sticky;
        top: 0;
        z-index: 100;
    }

    .nav-links {
        display: flex;
        gap: 2rem;
        list-style: none;
    }

    .nav-link {
        color: white;
        text-decoration: none;
        padding: 0.5rem 1rem;
        border-radius: 4px;
        transition: background 0.2s;
    }

    .nav-link:hover {
        background: rgba(255, 255, 255, 0.2);
    }

    .content {
        padding: 2rem;
    }

    .section {
        margin-bottom: 3rem;
        scroll-margin-top: 5rem;
    }

    .section-title {
        font-size: 2rem;
        margin-bottom: 1.5rem;
        color: #0066cc;
        border-bottom: 2px solid #0066cc;
        padding-bottom: 0.5rem;
    }

    @media (max-width: 768px) {
        .archive-container {
            margin: 0;
        }

        .content {
            padding: 1rem;
        }

        .nav-links {
            flex-direction: column;
            gap: 0.5rem;
        }
    }
    """
  end

  defp generate_print_css do
    """
    @media print {
        .navigation {
            display: none;
        }

        .archive-container {
            background: white;
            box-shadow: none;
        }

        .content {
            padding: 0;
        }

        .section {
            page-break-inside: avoid;
        }

        .section-title {
            page-break-after: avoid;
        }
    }
    """
  end

  defp generate_docx_css(options) do
    template_style = Map.get(options, "template_style", "professional")

    """
    body {
        font-family: 'Calibri', sans-serif;
        font-size: 11pt;
        line-height: 1.4;
        margin: 1in;
    }

    h1 {
        font-size: 18pt;
        font-weight: bold;
        margin-bottom: 12pt;
    }

    h2 {
        font-size: 14pt;
        font-weight: bold;
        margin-top: 18pt;
        margin-bottom: 6pt;
        border-bottom: 1px solid #000;
    }

    p {
        margin-bottom: 6pt;
    }

    .contact-info {
        text-align: center;
        margin-bottom: 18pt;
    }
    """
  end

  # Content Rendering Functions
  defp render_ats_header(contact) do
    if contact do
      """
      <div class="header">
          <div class="name">#{contact.name || "Name"}</div>
          <div class="contact-info">
              #{contact.email || ""} • #{contact.phone || ""}<br>
              #{if contact.linkedin, do: contact.linkedin, else: ""}
          </div>
      </div>
      """
    else
      ""
    end
  end

  defp render_ats_summary(summary) do
    if summary && String.length(summary) > 0 do
      """
      <div class="section">
          <div class="section-title">Professional Summary</div>
          <p>#{summary}</p>
      </div>
      """
    else
      ""
    end
  end

  defp render_ats_experience(experience) do
    if experience && length(experience) > 0 do
      experience_html =
        experience
        |> Enum.map(fn exp ->
          """
          <div class="job-entry">
              <div class="job-title">#{exp.title}</div>
              <div class="company">#{exp.company}</div>
              <div class="dates">#{exp.dates}</div>
              <div class="description">#{exp.description}</div>
          </div>
          """
        end)
        |> Enum.join("")

      """
      <div class="section">
          <div class="section-title">Professional Experience</div>
          #{experience_html}
      </div>
      """
    else
      ""
    end
  end

  defp render_ats_education(education) do
    if education && length(education) > 0 do
      education_html =
        education
        |> Enum.map(fn edu ->
          """
          <div class="education-entry">
              <strong>#{edu.degree}</strong><br>
              #{edu.institution} • #{edu.year}
          </div>
          """
        end)
        |> Enum.join("")

      """
      <div class="section">
          <div class="section-title">Education</div>
          #{education_html}
      </div>
      """
    else
      ""
    end
  end

  defp render_ats_skills(skills) do
    if skills && length(skills) > 0 do
      skills_text = Enum.join(skills, ", ")

      """
      <div class="section">
          <div class="section-title">Skills</div>
          <div class="skills-list">#{skills_text}</div>
      </div>
      """
    else
      ""
    end
  end

  # Additional rendering functions for other templates would go here...
  defp render_portfolio_header(export_data), do: "<div class='portfolio-header'>#{export_data.metadata.title}</div>"
  defp render_portfolio_sections(sections), do: "<div class='sections'>Portfolio sections...</div>"
  defp render_navigation(sections), do: "<nav class='navigation'>Navigation...</nav>"
  defp render_archive_content(export_data), do: "<div class='archive-content'>Archive content...</div>"
  defp render_docx_content(export_data), do: "<div class='docx-content'>DOCX content...</div>"

  # Utility Functions
  defp save_export_file(content, export_data, extension) do
    filename = generate_filename(export_data, extension)
    file_path = Path.join([get_export_directory(), filename])

    case File.write(file_path, content) do
      :ok ->
        file_info = %{
          filename: filename,
          file_path: file_path,
          download_url: generate_download_url(filename),
          file_size: byte_size(content),
          content_type: get_content_type(extension),
          created_at: DateTime.utc_now()
        }

        # Store in temporary file manager for cleanup
        TempFileManager.register_temp_file(filename, file_path, DateTime.add(DateTime.utc_now(), 48, :hour))

        {:ok, file_info}

      {:error, reason} ->
        {:error, "Failed to save export file: #{reason}"}
    end
  end

  defp generate_filename(export_data, extension) do
    portfolio_title =
      export_data.portfolio.title
      |> String.replace(~r/[^\w\s-]/, "")
      |> String.replace(~r/\s+/, "_")
      |> String.slice(0, 50)

    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{portfolio_title}_#{export_data.format}_#{timestamp}.#{extension}"
  end

  defp generate_download_url(filename) do
    "/api/exports/download/#{filename}"
  end

  defp get_content_type("pdf"), do: "application/pdf"
  defp get_content_type("html"), do: "text/html"
  defp get_content_type("docx"), do: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  defp get_content_type(_), do: "application/octet-stream"

  defp get_export_directory do
    export_dir = Path.join([Application.get_env(:frestyl, :uploads_directory, "priv/static"), "exports"])
    File.mkdir_p!(export_dir)
    export_dir
  end

  defp get_docx_template_path(template_style) do
    Path.join([
      :code.priv_dir(:frestyl),
      "templates",
      "docx",
      "#{template_style}_template.docx"
    ])
  end

  defp embed_html_assets(html_content) do
    # This would embed CSS, images, and other assets inline
    # For now, return as-is - implement asset embedding as needed
    html_content
  end

  defp get_portfolio_owner_name(portfolio) do
    case Portfolios.get_portfolio_owner(portfolio) do
      %{name: name} when is_binary(name) -> name
      %{first_name: first, last_name: last} -> "#{first} #{last}"
      _ -> "Portfolio Owner"
    end
  end

  # Section extraction functions - these would interface with your portfolio schema
  defp extract_contact_section(portfolio) do
    # Extract contact information from portfolio
    # This is a placeholder - implement based on your portfolio schema
    %{
      name: portfolio.user.name || "#{portfolio.user.first_name} #{portfolio.user.last_name}",
      email: portfolio.user.email,
      phone: portfolio.contact_phone,
      linkedin: portfolio.linkedin_url,
      github: portfolio.github_url
    }
  end

  defp extract_summary_section(portfolio) do
    portfolio.summary || portfolio.bio || ""
  end

  defp extract_experience_section(portfolio) do
    # Extract work experience from portfolio
    # This is a placeholder - implement based on your portfolio schema
    portfolio.work_experiences || []
  end

  defp extract_education_section(portfolio) do
    # Extract education from portfolio
    # This is a placeholder - implement based on your portfolio schema
    portfolio.education || []
  end

  defp extract_skills_section(portfolio) do
    # Extract skills from portfolio
    # This is a placeholder - implement based on your portfolio schema
    portfolio.skills || []
  end

  defp extract_projects_section(portfolio) do
    # Extract projects from portfolio
    # This is a placeholder - implement based on your portfolio schema
    portfolio.projects || []
  end

  defp extract_certifications_section(portfolio) do
    # Extract certifications from portfolio
    # This is a placeholder - implement based on your portfolio schema
    portfolio.certifications || []
  end

  defp extract_testimonials_section(portfolio) do
    # Extract testimonials from portfolio
    # This is a placeholder - implement based on your portfolio schema
    portfolio.testimonials || []
  end
end
