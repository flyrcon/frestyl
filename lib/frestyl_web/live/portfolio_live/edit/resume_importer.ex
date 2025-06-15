defmodule FrestylWeb.PortfolioLive.Edit.ResumeImporter do
  @moduledoc """
  Phase 3: Resume import logic without direct socket manipulation.
  Returns data/results that the Edit module can use to update the socket.
  """

  alias Frestyl.Portfolios
  alias Frestyl.ResumeParser
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3, push_navigate: 2]

  # These functions return data - they don't manipulate sockets directly

  def show_import_modal do
    # Returns initial state for resume import
    %{
      show_resume_import_modal: true,
      resume_parsing_state: :idle,
      parsed_resume_data: nil,
      resume_error_message: nil,
      import_progress: 0,
      sections_to_import: %{}
    }
  end

  def hide_import_modal do
    # Returns state to hide modal
    %{
      show_resume_import_modal: false,
      parsed_resume_data: nil,
      resume_parsing_state: :idle,
      resume_error_message: nil,
      import_progress: 0,
      sections_to_import: %{}
    }
  end

  def start_parsing do
    # Returns state for parsing started
    %{
      resume_parsing_state: :parsing,
      import_progress: 10
    }
  end

  def parsing_error(reason) do
    # Returns error state
    %{
      resume_parsing_state: :error,
      resume_error_message: reason,
      import_progress: 0
    }
  end

  def parsing_complete(parsed_data) do
    # Returns successful parsing state
    sections_to_import = initialize_section_selections(parsed_data)

    %{
      parsed_resume_data: parsed_data,
      resume_parsing_state: :parsed,
      sections_to_import: sections_to_import,
      import_progress: 100
    }
  end

  def reset_parsing do
    # Returns reset state
    %{
      resume_parsing_state: :idle,
      parsed_resume_data: nil,
      resume_error_message: nil,
      import_progress: 0
    }
  end

  # Process uploaded file - returns result
  def process_uploaded_file(file_path, filename) do
    try do
      # Use filename to determine file type since temp files don't have extensions
      case ResumeParser.parse_resume_with_filename(file_path, filename) do
        {:ok, parsed_data} ->
          enhanced_data = enhance_parsed_data_for_portfolio(parsed_data, filename)
          {:ok, enhanced_data}
        {:error, reason} ->
          {:error, "Parsing failed: #{reason}"}
      end
    rescue
      error ->
        {:error, "File processing error: #{Exception.message(error)}"}
    end
  end

  # Import sections to portfolio - returns result
  def import_sections_to_portfolio(portfolio, parsed_data, section_selections) do
    case create_sections_from_resume_data(portfolio, parsed_data, section_selections) do
      {:ok, created_sections} ->
        updated_sections = Portfolios.list_portfolio_sections(portfolio.id)

        result = %{
          sections: updated_sections,
          show_resume_import_modal: false,
          parsed_resume_data: nil,
          resume_parsing_state: :idle,
          import_progress: 100,
          flash_message: {:info, "Successfully imported #{length(created_sections)} sections from resume!"}
        }

        {:ok, result}

      {:error, reason} ->
        error_result = %{
          resume_parsing_state: :error,
          resume_error_message: "Failed to import sections: #{reason}",
          flash_message: {:error, "Failed to import sections: #{reason}"}
        }

        {:error, error_result}
    end
  end

  # Helper function to get section mappings from params
  def get_section_mappings_from_params(params) do
    case params do
      %{"section" => mappings} when is_map(mappings) -> mappings
      %{} = params ->
        params
        |> Enum.filter(fn {key, _value} -> String.starts_with?(to_string(key), "section_") end)
        |> Enum.into(%{}, fn {key, value} ->
          section_key = String.replace(to_string(key), "section_", "")
          {section_key, value}
        end)
      _ -> %{}
    end
  end

  # PRIVATE HELPER FUNCTIONS (all the parsing logic)

  defp enhance_parsed_data_for_portfolio(raw_data, filename) do
    %{
      filename: filename,
      personal_info: extract_safe(raw_data, "personal_info", %{}),
      professional_summary: extract_safe(raw_data, "professional_summary", ""),
      work_experience: format_work_experience_for_portfolio(raw_data),
      education: format_education_for_portfolio(raw_data),
      skills: format_skills_for_portfolio(raw_data),
      projects: format_projects_for_portfolio(raw_data),
      certifications: format_certifications_for_portfolio(raw_data),
      achievements: extract_safe(raw_data, "achievements", ""),
      languages: extract_safe(raw_data, "languages", "")
    }
  end

  defp format_work_experience_for_portfolio(raw_data) do
    case extract_safe(raw_data, "work_experience", []) do
      list when is_list(list) ->
        Enum.map(list, &format_job_entry/1)
      text when is_binary(text) ->
        parse_experience_text_to_jobs(text)
      _ -> []
    end
  end

  defp format_job_entry(item) when is_map(item) do
    %{
      "company" => Map.get(item, "company", Map.get(item, :company, "")),
      "title" => Map.get(item, "title", Map.get(item, :title, Map.get(item, "position", ""))),
      "start_date" => Map.get(item, "start_date", Map.get(item, :start_date, "")),
      "end_date" => Map.get(item, "end_date", Map.get(item, :end_date, "")),
      "current" => Map.get(item, "current", Map.get(item, :current, false)),
      "description" => Map.get(item, "description", Map.get(item, :description, "")),
      "highlights" => Map.get(item, "highlights", Map.get(item, :highlights, [])),
      "technologies" => Map.get(item, "technologies", Map.get(item, :technologies, []))
    }
  end

  defp format_job_entry(text) when is_binary(text) do
    %{
      "company" => "",
      "title" => "",
      "start_date" => "",
      "end_date" => "",
      "current" => false,
      "description" => text,
      "highlights" => [],
      "technologies" => []
    }
  end

  defp parse_experience_text_to_jobs(text) do
    # Simple implementation - can be enhanced
    [%{
      "company" => "",
      "title" => "",
      "start_date" => "",
      "end_date" => "",
      "current" => false,
      "description" => text,
      "highlights" => [],
      "technologies" => []
    }]
  end

  defp format_education_for_portfolio(raw_data) do
    case extract_safe(raw_data, "education", []) do
      list when is_list(list) -> Enum.map(list, &format_education_entry/1)
      text when is_binary(text) -> [format_education_entry(text)]
      _ -> []
    end
  end

  defp format_education_entry(item) when is_map(item) do
    %{
      "institution" => Map.get(item, "institution", Map.get(item, :institution, "")),
      "degree" => Map.get(item, "degree", Map.get(item, :degree, "")),
      "field" => Map.get(item, "field", Map.get(item, :field, "")),
      "start_date" => Map.get(item, "start_date", Map.get(item, :start_date, "")),
      "end_date" => Map.get(item, "end_date", Map.get(item, :end_date, "")),
      "gpa" => Map.get(item, "gpa", Map.get(item, :gpa, "")),
      "description" => Map.get(item, "description", Map.get(item, :description, ""))
    }
  end

  defp format_education_entry(text) when is_binary(text) do
    %{
      "institution" => "",
      "degree" => "",
      "field" => "",
      "start_date" => "",
      "end_date" => "",
      "gpa" => "",
      "description" => text
    }
  end

  defp format_skills_for_portfolio(raw_data) do
    case extract_safe(raw_data, "skills", []) do
      list when is_list(list) -> Enum.map(list, &format_skill_entry/1)
      text when is_binary(text) -> parse_skills_text(text)
      _ -> []
    end
  end

  defp format_skill_entry(item) when is_map(item) do
    %{
      "name" => Map.get(item, "name", Map.get(item, :name, to_string(item))),
      "level" => Map.get(item, "level", Map.get(item, :level, "intermediate")),
      "category" => Map.get(item, "category", Map.get(item, :category, "technical"))
    }
  end

  defp format_skill_entry(skill) when is_binary(skill) do
    %{
      "name" => skill,
      "level" => "intermediate",
      "category" => "technical"
    }
  end

  defp parse_skills_text(text) do
    text
    |> String.split(~r/[,\n|;]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&format_skill_entry/1)
  end

  defp format_projects_for_portfolio(raw_data) do
    case extract_safe(raw_data, "projects", []) do
      list when is_list(list) -> Enum.map(list, &format_project_entry/1)
      text when is_binary(text) -> [format_project_entry(text)]
      _ -> []
    end
  end

  defp format_project_entry(item) when is_map(item) do
    %{
      "title" => Map.get(item, "title", Map.get(item, :title, "")),
      "description" => Map.get(item, "description", Map.get(item, :description, "")),
      "technologies" => Map.get(item, "technologies", Map.get(item, :technologies, [])),
      "url" => Map.get(item, "url", Map.get(item, :url, "")),
      "github_url" => Map.get(item, "github_url", Map.get(item, :github_url, ""))
    }
  end

  defp format_project_entry(text) when is_binary(text) do
    %{
      "title" => "Project",
      "description" => text,
      "technologies" => [],
      "url" => "",
      "github_url" => ""
    }
  end

  defp format_certifications_for_portfolio(raw_data) do
    case extract_safe(raw_data, "certifications", []) do
      list when is_list(list) -> Enum.map(list, &format_certification_entry/1)
      text when is_binary(text) -> [format_certification_entry(text)]
      _ -> []
    end
  end

  defp format_certification_entry(item) when is_map(item) do
    %{
      "title" => Map.get(item, "name", Map.get(item, :name, Map.get(item, "title", ""))),
      "provider" => Map.get(item, "provider", Map.get(item, :provider, "")),
      "date" => Map.get(item, "date", Map.get(item, :date, "")),
      "description" => Map.get(item, "description", Map.get(item, :description, ""))
    }
  end

  defp format_certification_entry(text) when is_binary(text) do
    %{
      "title" => text,
      "provider" => "",
      "date" => "",
      "description" => ""
    }
  end

  defp extract_safe(data, key, default) do
    case data do
      %{} -> Map.get(data, key, Map.get(data, String.to_atom(key), default))
      _ -> default
    end
  end

  defp initialize_section_selections(parsed_data) do
    %{
      "personal_info" => true,
      "professional_summary" => has_content?(parsed_data.professional_summary),
      "work_experience" => has_list_content?(parsed_data.work_experience),
      "education" => has_list_content?(parsed_data.education),
      "skills" => has_list_content?(parsed_data.skills),
      "projects" => has_list_content?(parsed_data.projects),
      "certifications" => has_list_content?(parsed_data.certifications)
    }
  end

  defp has_content?(content) when is_binary(content), do: String.trim(content) != ""
  defp has_content?(_), do: false

  defp has_list_content?(list) when is_list(list), do: length(list) > 0
  defp has_list_content?(_), do: false

  defp create_sections_from_resume_data(portfolio, parsed_data, section_mappings) do
    existing_sections = Portfolios.list_portfolio_sections(portfolio.id)
    max_position = case existing_sections do
      [] -> 0
      sections -> Enum.map(sections, & &1.position) |> Enum.max()
    end

    results = []
    position_counter = max_position

    section_results = Enum.reduce(section_mappings, {:ok, [], position_counter}, fn
      {section_type, "true"}, {:ok, acc, position} ->
        case create_portfolio_section_from_resume(portfolio, section_type, parsed_data, position + 1) do
          {:ok, section} -> {:ok, [section | acc], position + 1}
          {:error, reason} -> {:error, reason}
        end

      {_section_type, _value}, {:ok, acc, position} ->
        {:ok, acc, position}

      {_section_type, _value}, {:error, reason} ->
        {:error, reason}
    end)

    case section_results do
      {:ok, sections, _final_position} -> {:ok, Enum.reverse(sections)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_portfolio_section_from_resume(portfolio, section_type, parsed_data, position) do
    {portfolio_section_type, section_title, content} = map_resume_section_to_portfolio(section_type, parsed_data)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: section_title,
      section_type: portfolio_section_type,
      content: content,
      position: position,
      visible: true
    }

    Portfolios.create_section(section_attrs)
  end

  defp map_resume_section_to_portfolio(section_type, parsed_data) do
    case section_type do
      "personal_info" ->
        {:contact, "Contact Information", %{
          "email" => get_in(parsed_data, [:personal_info, "email"]) || "",
          "phone" => get_in(parsed_data, [:personal_info, "phone"]) || "",
          "location" => get_in(parsed_data, [:personal_info, "location"]) || "",
          "name" => get_in(parsed_data, [:personal_info, "name"]) || ""
        }}

      "professional_summary" ->
        {:intro, "Professional Summary", %{
          "headline" => "Professional Summary",
          "summary" => parsed_data.professional_summary || "",
          "location" => get_in(parsed_data, [:personal_info, "location"]) || ""
        }}

      "work_experience" ->
        {:experience, "Work Experience", %{
          "jobs" => parsed_data.work_experience || []
        }}

      "education" ->
        {:education, "Education", %{
          "education" => parsed_data.education || []
        }}

      "skills" ->
        {:skills, "Skills & Expertise", %{
          "skills" => parsed_data.skills || []
        }}

      "projects" ->
        {:projects, "Projects", %{
          "projects" => parsed_data.projects || []
        }}

      "certifications" ->
        {:achievements, "Certifications & Achievements", %{
          "achievements" => parsed_data.certifications || []
        }}

      _ ->
        {:custom, format_section_title(section_type), %{
          "title" => format_section_title(section_type),
          "content" => "",
          "layout" => "default"
        }}
    end
  end

  defp format_section_title(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
