# lib/frestyl_web/live/portfolio_live/resume_parser.ex - Enhanced for Phase 2

defmodule FrestylWeb.PortfolioLive.ResumeParser do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.ResumeParser

  @impl true
  def mount(%{"portfolio_id" => portfolio_id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    # Ensure user owns this portfolio
    if portfolio.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this portfolio.")
       |> push_navigate(to: "/portfolios")}
    else
      limits = Portfolios.get_portfolio_limits(socket.assigns.current_user)

      socket =
        socket
        |> assign(:page_title, "Resume Importer")
        |> assign(:portfolio, portfolio)
        |> assign(:parsed_data, nil)
        |> assign(:processing, false)
        |> assign(:processing_stage, :idle) # :idle, :uploading, :parsing, :complete, :error
        |> assign(:processing_message, "")
        |> assign(:parsing_progress, 0)
        |> assign(:error_message, nil)
        |> assign(:limits, limits)
        |> assign(:ats_available, limits.ats_optimization)
        |> assign(:sections_to_import, %{}) # Track which sections user wants to import
        |> allow_upload(:resume,
            accept: ~w(.pdf .doc .docx .txt .rtf),
            max_entries: 1,
            max_file_size: 10 * 1_048_576) # Increased to 10MB for multi-page documents

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    # Validate file types and sizes
    {:noreply, socket}
  end

  @impl true
  def handle_event("process_resume", _params, socket) do
    socket =
      socket
      |> assign(:processing, true)
      |> assign(:processing_stage, :uploading)
      |> assign(:processing_message, "Uploading your resume...")
      |> assign(:parsing_progress, 10)

    case uploaded_entries(socket, :resume) do
      {[entry], _} ->
        # Process the resume file in a background task
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          process_resume_file_enhanced(socket, path, entry.client_name)
        end)

      _ ->
        {:noreply,
         socket
         |> assign(:processing, false)
         |> assign(:processing_stage, :error)
         |> assign(:error_message, "Please upload a resume file.")
         |> put_flash(:error, "Please upload a resume file.")}
    end
  end

  @impl true
  def handle_event("import_to_portfolio", %{"section" => section_selections}, socket) do
    portfolio = socket.assigns.portfolio
    parsed_data = socket.assigns.parsed_data

    if parsed_data do
      socket =
        socket
        |> assign(:processing, true)
        |> assign(:processing_stage, :importing)
        |> assign(:processing_message, "Importing selected sections...")

      # Import sections in background task
      Task.start(fn ->
        result = import_sections_to_portfolio(portfolio, parsed_data, section_selections)
        send(self(), {:import_complete, result})
      end)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "No parsed data available.")}
    end
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section_type}, socket) do
    current_selections = socket.assigns.sections_to_import
    new_selections = Map.update(current_selections, section_type, true, &(!&1))

    {:noreply, assign(socket, :sections_to_import, new_selections)}
  end

  @impl true
  def handle_event("optimize_for_ats", %{"job_description" => job_description}, socket) do
    if socket.assigns.ats_available and socket.assigns.parsed_data do
      socket =
        socket
        |> assign(:processing, true)
        |> assign(:processing_stage, :optimizing)
        |> assign(:processing_message, "Optimizing resume for ATS...")

      # In a real implementation, this would call an AI service
      Task.start(fn ->
        # Simulate ATS optimization processing
        :timer.sleep(3000)

        # For now, return enhanced data (in production, this would be AI-optimized)
        optimized_data = optimize_resume_data(socket.assigns.parsed_data, job_description)
        send(self(), {:ats_optimization_complete, optimized_data})
      end)

      {:noreply, socket}
    else
      message = cond do
        !socket.assigns.ats_available -> "ATS optimization requires a premium subscription."
        !socket.assigns.parsed_data -> "Please upload and process a resume first."
        true -> "ATS optimization is not available."
      end

      {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("retry_processing", _params, socket) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:processing_stage, :idle)
      |> assign(:parsed_data, nil)
      |> assign(:error_message, nil)
      |> assign(:parsing_progress, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :resume, ref)}
  end

  # Handle async processing results
  @impl true
  def handle_info({:parsing_progress, stage, message, progress}, socket) do
    socket =
      socket
      |> assign(:processing_stage, stage)
      |> assign(:processing_message, message)
      |> assign(:parsing_progress, progress)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:parsing_complete, parsed_data}, socket) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:processing_stage, :complete)
      |> assign(:processing_message, "Resume processed successfully!")
      |> assign(:parsing_progress, 100)
      |> assign(:parsed_data, parsed_data)
      |> assign(:sections_to_import, initialize_section_selections(parsed_data))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:parsing_error, reason}, socket) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:processing_stage, :error)
      |> assign(:error_message, reason)
      |> assign(:parsing_progress, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:import_complete, {:ok, imported_count}}, socket) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:processing_stage, :idle)
      |> put_flash(:info, "Successfully imported #{imported_count} sections to your portfolio!")
      |> push_navigate(to: "/portfolios/#{socket.assigns.portfolio.id}/edit")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:import_complete, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:processing_stage, :error)
      |> assign(:error_message, "Import failed: #{reason}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ats_optimization_complete, optimized_data}, socket) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:processing_stage, :complete)
      |> assign(:parsed_data, optimized_data)
      |> put_flash(:info, "Resume optimized for ATS successfully!")

    {:noreply, socket}
  end

  # Enhanced resume processing with real parser integration
  defp process_resume_file_enhanced(socket, file_path, filename) do
    Task.start(fn ->
      try do
        # Progress updates
        send(self(), {:parsing_progress, :parsing, "Extracting text from #{filename}...", 25})

        # Use the enhanced ResumeParser
        case ResumeParser.parse_resume(file_path) do
          {:ok, parsed_data} ->
            send(self(), {:parsing_progress, :parsing, "Processing extracted data...", 75})

            # Transform the data to match our UI expectations
            enhanced_data = enhance_parsed_data(parsed_data, filename)

            send(self(), {:parsing_complete, enhanced_data})

          {:error, reason} ->
            send(self(), {:parsing_error, reason})
        end
      rescue
        error ->
          send(self(), {:parsing_error, "Processing failed: #{Exception.message(error)}"})
      end
    end)

    {:noreply, socket}
  end

  # Transform parsed data to match UI expectations and add enhancements
  defp enhance_parsed_data(raw_parsed_data, filename) do
    personal_info = extract_personal_info(raw_parsed_data)

    %{
      filename: filename,
      personal_info: personal_info,
      professional_summary: Map.get(raw_parsed_data, "professional_summary", ""),
      work_experience: format_work_experience_list(raw_parsed_data),
      education: format_education_list(raw_parsed_data),
      skills: format_skills_list(raw_parsed_data),
      projects: format_projects_list(raw_parsed_data),
      certifications: format_certifications_list(raw_parsed_data),
      achievements: Map.get(raw_parsed_data, "achievements", ""),
      languages: Map.get(raw_parsed_data, "languages", ""),
      additional_sections: get_additional_sections(raw_parsed_data)
    }
  end

  defp extract_personal_info(parsed_data) do
    case Map.get(parsed_data, "personal_info") do
      %{} = info -> info
      _ ->
        # Extract from other sections if personal_info not available
        %{
          name: extract_name_from_data(parsed_data),
          email: extract_email_from_data(parsed_data),
          phone: extract_phone_from_data(parsed_data),
          location: extract_location_from_data(parsed_data)
        }
    end
  end

  defp format_work_experience_list(parsed_data) do
    case Map.get(parsed_data, "work_experience") do
      list when is_list(list) ->
        Enum.map(list, &format_work_experience_item/1)
      text when is_binary(text) ->
        # Parse text into structured format
        parse_experience_text(text)
      _ -> []
    end
  end

  defp format_work_experience_item(item) when is_map(item) do
    %{
      company: Map.get(item, "company", ""),
      title: Map.get(item, "title", Map.get(item, "position", "")),
      start_date: Map.get(item, "start_date", ""),
      end_date: Map.get(item, "end_date", ""),
      current: Map.get(item, "current", false),
      description: Map.get(item, "description", ""),
      highlights: Map.get(item, "highlights", []),
      technologies: Map.get(item, "technologies", [])
    }
  end

  defp format_work_experience_item(text) when is_binary(text) do
    %{
      company: "",
      title: "",
      start_date: "",
      end_date: "",
      current: false,
      description: text,
      highlights: [],
      technologies: []
    }
  end

  defp format_education_list(parsed_data) do
    case Map.get(parsed_data, "education") do
      list when is_list(list) ->
        Enum.map(list, &format_education_item/1)
      text when is_binary(text) ->
        parse_education_text(text)
      _ -> []
    end
  end

  defp format_education_item(item) when is_map(item) do
    %{
      institution: Map.get(item, "institution", Map.get(item, "school", "")),
      degree: Map.get(item, "degree", ""),
      field: Map.get(item, "field", ""),
      start_date: Map.get(item, "start_date", ""),
      end_date: Map.get(item, "end_date", Map.get(item, "year", "")),
      gpa: Map.get(item, "gpa", ""),
      description: Map.get(item, "description", "")
    }
  end

  defp format_education_item(text) when is_binary(text) do
    %{
      institution: "",
      degree: "",
      field: "",
      start_date: "",
      end_date: "",
      gpa: "",
      description: text
    }
  end

  defp format_skills_list(parsed_data) do
    case Map.get(parsed_data, "skills") do
      list when is_list(list) ->
        Enum.map(list, fn
          %{"name" => name} = skill -> Map.get(skill, "name", name)
          skill when is_binary(skill) -> skill
          _ -> ""
        end)
        |> Enum.reject(&(&1 == ""))
      text when is_binary(text) ->
        String.split(text, ",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      _ -> []
    end
  end

  defp format_projects_list(parsed_data) do
    case Map.get(parsed_data, "projects") do
      list when is_list(list) ->
        Enum.map(list, &format_project_item/1)
      text when is_binary(text) ->
        parse_projects_text(text)
      _ -> []
    end
  end

  defp format_project_item(item) when is_map(item) do
    %{
      title: Map.get(item, "title", ""),
      description: Map.get(item, "description", ""),
      technologies: Map.get(item, "technologies", []),
      url: Map.get(item, "url", ""),
      github_url: Map.get(item, "github_url", "")
    }
  end

  defp format_project_item(text) when is_binary(text) do
    %{
      title: "Project",
      description: text,
      technologies: [],
      url: "",
      github_url: ""
    }
  end

  defp format_certifications_list(parsed_data) do
    case Map.get(parsed_data, "certifications") do
      list when is_list(list) ->
        Enum.map(list, &format_certification_item/1)
      text when is_binary(text) ->
        parse_certifications_text(text)
      _ -> []
    end
  end

  defp format_certification_item(item) when is_map(item) do
    %{
      name: Map.get(item, "name", ""),
      provider: Map.get(item, "provider", ""),
      date: Map.get(item, "date", Map.get(item, "year", "")),
      credential_id: Map.get(item, "credential_id", "")
    }
  end

  defp format_certification_item(text) when is_binary(text) do
    %{
      name: text,
      provider: "",
      date: "",
      credential_id: ""
    }
  end

  # Helper functions for text parsing when structured data isn't available
  defp parse_experience_text(text) do
    # Simple parsing - in production you might want more sophisticated parsing
    lines = String.split(text, "\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    # Group lines into job entries (simple heuristic)
    [%{
      company: "",
      title: "",
      start_date: "",
      end_date: "",
      current: false,
      description: Enum.join(lines, "\n"),
      highlights: [],
      technologies: []
    }]
  end

  defp parse_education_text(text) do
    [%{
      institution: "",
      degree: "",
      field: "",
      start_date: "",
      end_date: "",
      gpa: "",
      description: text
    }]
  end

  defp parse_projects_text(text) do
    [%{
      title: "Projects",
      description: text,
      technologies: [],
      url: "",
      github_url: ""
    }]
  end

  defp parse_certifications_text(text) do
    String.split(text, "\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn cert ->
      %{
        name: cert,
        provider: "",
        date: "",
        credential_id: ""
      }
    end)
  end

  # Data extraction helpers
  defp extract_name_from_data(parsed_data) do
    # Try to extract name from various possible locations
    Enum.find_value([
      get_in(parsed_data, ["personal_info", "name"]),
      get_in(parsed_data, ["contact", "name"]),
      get_in(parsed_data, ["header", "name"])
    ], &(&1)) || ""
  end

  defp extract_email_from_data(parsed_data) do
    Enum.find_value([
      get_in(parsed_data, ["personal_info", "email"]),
      get_in(parsed_data, ["contact", "email"])
    ], &(&1)) || ""
  end

  defp extract_phone_from_data(parsed_data) do
    Enum.find_value([
      get_in(parsed_data, ["personal_info", "phone"]),
      get_in(parsed_data, ["contact", "phone"])
    ], &(&1)) || ""
  end

  defp extract_location_from_data(parsed_data) do
    Enum.find_value([
      get_in(parsed_data, ["personal_info", "location"]),
      get_in(parsed_data, ["contact", "location"])
    ], &(&1)) || ""
  end

  defp get_additional_sections(parsed_data) do
    # Get any sections that don't fit into standard categories
    known_sections = ["personal_info", "professional_summary", "work_experience",
                     "education", "skills", "projects", "certifications", "achievements", "languages"]

    parsed_data
    |> Enum.reject(fn {key, _value} -> key in known_sections end)
    |> Enum.into(%{})
  end

  defp initialize_section_selections(parsed_data) do
    # Initialize with all main sections selected by default
    %{
      "personal_info" => true,
      "professional_summary" => String.length(Map.get(parsed_data, :professional_summary, "")) > 0,
      "work_experience" => length(Map.get(parsed_data, :work_experience, [])) > 0,
      "education" => length(Map.get(parsed_data, :education, [])) > 0,
      "skills" => length(Map.get(parsed_data, :skills, [])) > 0,
      "projects" => length(Map.get(parsed_data, :projects, [])) > 0,
      "certifications" => length(Map.get(parsed_data, :certifications, [])) > 0
    }
  end

  # Import sections to portfolio
  defp import_sections_to_portfolio(portfolio, parsed_data, section_selections) do
    imported_count = 0

    try do
      # Import each selected section
      imported_count = Enum.reduce(section_selections, 0, fn {section_type, selected}, acc ->
        if selected == "true" do
          case import_section(portfolio, section_type, parsed_data) do
            {:ok, _section} -> acc + 1
            {:error, _reason} -> acc
          end
        else
          acc
        end
      end)

      {:ok, imported_count}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp import_section(portfolio, "personal_info", parsed_data) do
    update_contact_section(portfolio.id, parsed_data.personal_info)
  end

  defp import_section(portfolio, "professional_summary", parsed_data) do
    update_intro_section(portfolio.id, parsed_data.professional_summary)
  end

  defp import_section(portfolio, "work_experience", parsed_data) do
    update_experience_section(portfolio.id, parsed_data.work_experience)
  end

  defp import_section(portfolio, "education", parsed_data) do
    update_education_section(portfolio.id, parsed_data.education)
  end

  defp import_section(portfolio, "skills", parsed_data) do
    update_skills_section(portfolio.id, parsed_data.skills)
  end

  defp import_section(portfolio, "projects", parsed_data) do
    update_projects_section(portfolio.id, parsed_data.projects)
  end

  defp import_section(portfolio, "certifications", parsed_data) do
    update_certifications_section(portfolio.id, parsed_data.certifications)
  end

  defp import_section(_portfolio, _section_type, _parsed_data) do
    {:error, "Unknown section type"}
  end

  # Section update functions (enhanced from your originals)
  defp update_contact_section(portfolio_id, personal_info) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    contact_section = Enum.find(sections, fn s -> s.section_type == :contact end)

    contact_data = %{
      "email" => Map.get(personal_info, :email, ""),
      "phone" => Map.get(personal_info, :phone, ""),
      "location" => Map.get(personal_info, :location, ""),
      "name" => Map.get(personal_info, :name, "")
    }

    if contact_section do
      Portfolios.update_section(contact_section, %{content: contact_data})
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Contact Information",
        section_type: :contact,
        position: get_next_position(sections),
        content: contact_data,
        visible: true
      })
    end
  end

  defp update_intro_section(portfolio_id, summary) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    intro_section = Enum.find(sections, fn s -> s.section_type == :intro end)

    intro_data = %{
      "headline" => "Professional Summary",
      "summary" => summary,
      "location" => "",
      "website" => "",
      "social_links" => %{}
    }

    if intro_section do
      Portfolios.update_section(intro_section, %{content: intro_data})
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Professional Summary",
        section_type: :intro,
        position: get_next_position(sections),
        content: intro_data,
        visible: true
      })
    end
  end

  defp update_experience_section(portfolio_id, experience) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    experience_section = Enum.find(sections, fn s -> s.section_type == :experience end)

    experience_data = %{"jobs" => experience}

    if experience_section do
      Portfolios.update_section(experience_section, %{content: experience_data})
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Work Experience",
        section_type: :experience,
        position: get_next_position(sections),
        content: experience_data,
        visible: true
      })
    end
  end

  defp update_education_section(portfolio_id, education) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    education_section = Enum.find(sections, fn s -> s.section_type == :education end)

    education_data = %{"education" => education}

    if education_section do
      Portfolios.update_section(education_section, %{content: education_data})
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Education",
        section_type: :education,
        position: get_next_position(sections),
        content: education_data,
        visible: true
      })
    end
  end

  defp update_skills_section(portfolio_id, skills) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    skills_section = Enum.find(sections, fn s -> s.section_type == :skills end)

    # Convert skills list to the expected format
    formatted_skills = Enum.map(skills, fn skill ->
      %{
        "name" => skill,
        "level" => "intermediate",
        "category" => "general"
      }
    end)

    skills_data = %{"skills" => formatted_skills}

    if skills_section do
      Portfolios.update_section(skills_section, %{content: skills_data})
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Skills & Expertise",
        section_type: :skills,
        position: get_next_position(sections),
        content: skills_data,
        visible: true
      })
    end
  end

  defp update_projects_section(portfolio_id, projects) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    projects_section = Enum.find(sections, fn s -> s.section_type == :projects end)

    projects_data = %{"projects" => projects}

    if projects_section do
      Portfolios.update_section(projects_section, %{content: projects_data})
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Projects",
        section_type: :projects,
        position: get_next_position(sections),
        content: projects_data,
        visible: true
      })
    end
  end

  defp update_certifications_section(portfolio_id, certifications) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    cert_section = Enum.find(sections, fn s -> s.section_type == :achievements end)

    cert_data = %{"achievements" => certifications}

    if cert_section do
      Portfolios.update_section(cert_section, %{content: cert_data})
    else
      Portfolios.create_section(%{
        portfolio_id: portfolio_id,
        title: "Certifications & Achievements",
        section_type: :achievements,
        position: get_next_position(sections),
        content: cert_data,
        visible: true
      })
    end
  end

  defp get_next_position(sections) do
    case sections do
      [] -> 1
      sections -> Enum.map(sections, & &1.position) |> Enum.max() |> Kernel.+(1)
    end
  end

  # Mock ATS optimization (replace with real AI service in production)
  defp optimize_resume_data(parsed_data, job_description) do
    # In production, this would:
    # 1. Send parsed_data and job_description to AI service
    # 2. Get back optimized version with better keywords, formatting, etc.
    # 3. Return enhanced data

    # For now, just return the same data with a note
    Map.put(parsed_data, :ats_optimized, true)
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "You've selected too many files"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
