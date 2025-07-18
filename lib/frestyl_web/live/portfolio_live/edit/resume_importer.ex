# lib/frestyl_web/live/portfolio_live/edit/resume_importer.ex - CORRECTED VERSION
defmodule FrestylWeb.PortfolioLive.Edit.ResumeImporter do
  @moduledoc """
  Resume import logic that works with your original robust parser.
  Returns data/results that the Edit module can use to update the socket.
  """

  alias Frestyl.Portfolios
  alias Frestyl.ResumeParser

  require Logger

  # ============================================================================
  # PUBLIC API - Used by LiveView components
  # ============================================================================

  @doc """
  Process uploaded file with your original robust parser
  """
  def process_uploaded_file(file_path, filename) do
    Logger.info("🔍 IMPORT: Starting file processing for #{filename}")

    try do
      case ResumeParser.parse_resume_with_filename(file_path, filename) do
        {:ok, parsed_data} ->
          Logger.info("🔍 IMPORT: Raw parsed data keys: #{inspect(Map.keys(parsed_data))}")
          Logger.info("🔍 IMPORT: Work experience: #{inspect(Map.get(parsed_data, "work_experience", []))}")
          Logger.info("🔍 IMPORT: Skills: #{inspect(Enum.take(Map.get(parsed_data, "skills", []), 5))}")

          Logger.info("🔍 IMPORT: Parsing successful")
          enhanced_data = enhance_parsed_data_for_portfolio(parsed_data, filename)
          Logger.info("🔍 IMPORT: Enhancement complete, found #{map_size(enhanced_data)} sections")
          {:ok, enhanced_data}
        {:error, reason} ->
          Logger.error("🔍 IMPORT: Parsing failed: #{reason}")
          {:error, "Parsing failed: #{reason}"}
      end
    rescue
      error ->
        Logger.error("🔍 IMPORT: Exception during processing: #{Exception.message(error)}")
        {:error, "File processing error: #{Exception.message(error)}"}
    end
  end

  @doc """
  Import sections to portfolio with merge/replace options
  """
  def import_sections_to_portfolio(portfolio, parsed_data, section_selections, merge_options \\ %{}) do
    Logger.info("🔍 IMPORT: Starting section import")
    Logger.info("🔍 IMPORT: Portfolio ID: #{portfolio.id}")
    Logger.info("🔍 IMPORT: Selected sections: #{inspect(Map.keys(section_selections))}")

    case create_sections_from_resume_data(portfolio, parsed_data, section_selections) do
      {:ok, created_sections} ->
        updated_sections = Portfolios.list_portfolio_sections(portfolio.id)

        result = %{
          sections: updated_sections,
          show_resume_import_modal: false,
          parsed_resume_data: nil,
          resume_parsing_state: :idle,
          import_progress: 100,
          flash_message: "Successfully imported #{length(created_sections)} sections from resume!"
        }

        Logger.info("🔍 IMPORT: ✅ Import complete: #{length(created_sections)} sections processed")
        {:ok, result}

      {:error, reason} ->
        Logger.error("🔍 IMPORT: ❌ Import failed: #{reason}")
        error_result = %{
          resume_parsing_state: :error,
          resume_error_message: "Failed to import sections: #{reason}",
          flash_message: "Failed to import sections: #{reason}"
        }
        {:error, error_result}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  def get_section_mappings_from_params(params) do
    case params do
      %{"sections" => mappings} when is_map(mappings) ->
        mappings |> Map.reject(fn {key, _} -> key == "filename" end)
      %{} = params ->
        params
        |> Enum.filter(fn {key, _value} -> String.starts_with?(to_string(key), "sections[") end)
        |> Enum.into(%{}, fn {key, value} ->
          section_key = key
          |> to_string()
          |> String.replace(~r/^sections\[/, "")
          |> String.replace(~r/\]$/, "")
          {section_key, value}
        end)
        |> Map.reject(fn {key, _} -> key == "filename" end)
      _ -> %{}
    end
  end

defp initialize_section_selections(parsed_data) do
  available_sections = get_available_sections(parsed_data)

  # Convert to selection format with default true for available sections
  available_sections
  |> Enum.map(fn {section, has_content} ->
    {section, if(has_content, do: "true", else: "false")}
  end)
  |> Enum.into(%{})
end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp enhance_parsed_data_for_portfolio(raw_data, filename) do
    Logger.info("🔍 ENHANCE: Processing parsed data")

    %{
      filename: filename,
      personal_info: extract_safe_utf8(raw_data, "personal_info", %{}),
      professional_summary: extract_safe_utf8(raw_data, "professional_summary", ""),
      work_experience: format_work_experience_for_portfolio(raw_data),
      education: format_education_for_portfolio(raw_data),
      skills: format_skills_for_portfolio(raw_data),
      projects: format_projects_for_portfolio(raw_data),
      certifications: format_certifications_for_portfolio(raw_data),
      achievements: extract_safe_utf8(raw_data, "achievements", ""),
      languages: extract_safe_utf8(raw_data, "languages", ""),
      # Additional metadata
      sections_available: determine_available_sections(raw_data),
      content_quality: assess_content_quality(raw_data)
    }
  end

  defp format_skills_for_portfolio(raw_data) do
    case extract_safe(raw_data, "skills", []) do
      list when is_list(list) ->
        Enum.map(list, &format_skill_entry/1)
      text when is_binary(text) ->
        parse_skills_text_to_list(text)
      _ -> []
    end
  end

  defp format_skill_entry(item) when is_map(item) do
    case Map.get(item, "name") || Map.get(item, :name) do
      nil -> to_string(item)
      name -> name
    end
  end

  defp format_skill_entry(text) when is_binary(text), do: text
  defp format_skill_entry(item), do: to_string(item)

  defp parse_skills_text_to_list(text) do
    text
    |> String.split([",", ";", "\n", "•"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_safe(data, key, default) when is_map(data) do
    case Map.get(data, key) || Map.get(data, String.to_atom(key)) do
      nil -> default
      value -> value
    end
  end
  defp extract_safe(_data, _key, default), do: default

  defp extract_safe_utf8(data, key, default) do
    value = case data do
      %{} -> Map.get(data, key, Map.get(data, to_string(key), default))
      _ -> default
    end

    sanitize_utf8_for_database(value)
  end

  defp sanitize_utf8_for_database(value) when is_binary(value) do
    value
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")  # Remove control chars
    |> String.replace(~r/[\x80-\xFF]/, fn char ->
      if String.valid?(char), do: char, else: "?"
    end)
    |> String.normalize(:nfc)
    |> String.trim()
  end

  defp sanitize_utf8_for_database(value) when is_list(value) do
    Enum.map(value, &sanitize_utf8_for_database/1)
  end

  defp sanitize_utf8_for_database(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {k, sanitize_utf8_for_database(v)} end)
    |> Enum.into(%{})
  end

  defp sanitize_utf8_for_database(value), do: value

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
      "location" => Map.get(item, "location", Map.get(item, :location, "")),
      "employment_type" => Map.get(item, "employment_type", Map.get(item, :employment_type, "Full-time")),
      "responsibilities" => Map.get(item, "responsibilities", Map.get(item, :responsibilities, [])),
      "achievements" => Map.get(item, "achievements", Map.get(item, :achievements, [])),
      "skills" => Map.get(item, "skills", Map.get(item, :skills, []))
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
      "location" => "",
      "employment_type" => "Full-time",
      "responsibilities" => [],
      "achievements" => [],
      "skills" => []
    }
  end

  defp parse_experience_text_to_jobs(text) do
    # Split experience text by lines or common delimiters
    text
    |> String.split(["\n", ";", "•"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&format_job_entry/1)
  end

  defp format_responsibilities(job) do
    responsibilities = Map.get(job, "responsibilities", [])

    case responsibilities do
      list when is_list(list) and length(list) > 0 ->
        Enum.map(list, &sanitize_utf8_for_database/1)
      _ ->
        # Try to extract from description if no explicit responsibilities
        description = Map.get(job, "description", "")
        extract_bullet_points_from_text(description)
    end
  end

  defp extract_bullet_points_from_text(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.match?(&1, ~r/^[•\-\*]/))
    |> Enum.map(&String.replace(&1, ~r/^[•\-\*]\s*/, ""))
    |> Enum.map(&sanitize_utf8_for_database/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp get_job_list_field_safe(job, field) do
    case Map.get(job, field, []) do
      list when is_list(list) ->
        Enum.map(list, &sanitize_utf8_for_database/1)
      text when is_binary(text) ->
        [sanitize_utf8_for_database(text)]
      _ ->
        []
    end
  end

  defp format_education_for_portfolio(raw_data) do
    case extract_safe(raw_data, "education", []) do
      list when is_list(list) ->
        Enum.map(list, &format_education_entry/1)
      text when is_binary(text) ->
        parse_education_text_to_entries(text)
      _ -> []
    end
  end

  defp format_education_entry(item) when is_map(item) do
    %{
      "degree" => Map.get(item, "degree", Map.get(item, :degree, "")),
      "field" => Map.get(item, "field", Map.get(item, :field, Map.get(item, "major", ""))),
      "institution" => Map.get(item, "institution", Map.get(item, :institution, Map.get(item, "school", ""))),
      "location" => Map.get(item, "location", Map.get(item, :location, "")),
      "start_date" => Map.get(item, "start_date", Map.get(item, :start_date, "")),
      "end_date" => Map.get(item, "end_date", Map.get(item, :end_date, Map.get(item, "year", ""))),
      "status" => Map.get(item, "status", Map.get(item, :status, "Completed")),
      "gpa" => Map.get(item, "gpa", Map.get(item, :gpa, "")),
      "description" => Map.get(item, "description", Map.get(item, :description, "")),
      "relevant_coursework" => Map.get(item, "coursework", Map.get(item, :coursework, [])),
      "activities" => Map.get(item, "activities", Map.get(item, :activities, []))
    }
  end

  defp format_education_entry(text) when is_binary(text) do
    # Parse basic education text into structured format
    %{
      "degree" => "",
      "field" => "",
      "institution" => text,
      "location" => "",
      "start_date" => "",
      "end_date" => "",
      "status" => "Completed",
      "gpa" => "",
      "description" => "",
      "relevant_coursework" => [],
      "activities" => []
    }
  end

  defp has_education_content?(parsed_data) do
    education_data = extract_safe(parsed_data, "education", [])
    case education_data do
      list when is_list(list) ->
        length(list) > 0 && Enum.any?(list, fn edu ->
          # Check if education entry has meaningful content
          institution = Map.get(edu, "institution", "")
          degree = Map.get(edu, "degree", "")
          (is_binary(institution) && String.trim(institution) != "") ||
          (is_binary(degree) && String.trim(degree) != "")
        end)
      text when is_binary(text) -> String.trim(text) != ""
      _ -> false
    end
  end

  defp parse_education_text_to_entries(text) do
    # Split education text by lines or common delimiters
    text
    |> String.split(["\n", ";", "•"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&format_education_entry/1)
  end

  defp has_education_content?(parsed_data) do
    education_data = extract_safe(parsed_data, "education", [])
    case education_data do
      list when is_list(list) -> length(list) > 0
      text when is_binary(text) -> String.trim(text) != ""
      _ -> false
    end
  end

  # Update the section availability check:
  defp get_available_sections(parsed_data) do
    %{
      "personal_info" => has_content?(extract_safe_utf8(parsed_data, "personal_info", %{})),
      "professional_summary" => has_content?(extract_safe_utf8(parsed_data, "professional_summary", "")),
      "work_experience" => has_list_content?(extract_safe_utf8(parsed_data, "work_experience", [])),
      "education" => has_education_content?(parsed_data),  # Use the enhanced check
      "skills" => has_list_content?(extract_safe_utf8(parsed_data, "skills", [])),
      "projects" => has_list_content?(extract_safe_utf8(parsed_data, "projects", [])),
      "certifications" => has_list_content?(extract_safe_utf8(parsed_data, "certifications", []))
    }
  end

  defp format_projects_for_portfolio(raw_data) do
    case extract_safe(raw_data, "projects", []) do
      list when is_list(list) ->
        Enum.map(list, &format_project_entry/1)
      text when is_binary(text) ->
        parse_projects_text_to_list(text)
      _ -> []
    end
  end

  defp format_project_entry(item) when is_map(item) do
    %{
      "title" => Map.get(item, "title", Map.get(item, :title, "")),
      "description" => Map.get(item, "description", Map.get(item, :description, "")),
      "technologies" => Map.get(item, "technologies", Map.get(item, :technologies, [])),
      "role" => Map.get(item, "role", Map.get(item, :role, "")),
      "start_date" => Map.get(item, "start_date", Map.get(item, :start_date, "")),
      "end_date" => Map.get(item, "end_date", Map.get(item, :end_date, "")),
      "status" => Map.get(item, "status", Map.get(item, :status, "Completed")),
      "demo_url" => Map.get(item, "demo_url", Map.get(item, :demo_url, "")),
      "github_url" => Map.get(item, "github_url", Map.get(item, :github_url, ""))
    }
  end

  defp format_project_entry(text) when is_binary(text) do
    %{
      "title" => text,
      "description" => "",
      "technologies" => [],
      "role" => "",
      "start_date" => "",
      "end_date" => "",
      "status" => "Completed",
      "demo_url" => "",
      "github_url" => ""
    }
  end

  defp parse_projects_text_to_list(text) do
    text
    |> String.split(["\n", ";", "•"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&format_project_entry/1)
  end


  defp format_certifications_for_portfolio(raw_data) do
    case extract_safe(raw_data, "certifications", []) do
      list when is_list(list) ->
        Enum.map(list, &format_certification_entry/1)
      text when is_binary(text) ->
        parse_certifications_text_to_list(text)
      _ -> []
    end
  end

  defp format_certification_entry(item) when is_map(item) do
    %{
      "title" => Map.get(item, "title", Map.get(item, :title, Map.get(item, "name", ""))),
      "organization" => Map.get(item, "organization", Map.get(item, :organization, Map.get(item, "issuer", ""))),
      "date" => Map.get(item, "date", Map.get(item, :date, Map.get(item, "year", ""))),
      "description" => Map.get(item, "description", Map.get(item, :description, "")),
      "credential_id" => Map.get(item, "credential_id", Map.get(item, :credential_id, "")),
      "url" => Map.get(item, "url", Map.get(item, :url, ""))
    }
  end

  defp format_certification_entry(text) when is_binary(text) do
    %{
      "title" => text,
      "organization" => "",
      "date" => "",
      "description" => "",
      "credential_id" => "",
      "url" => ""
    }
  end

  defp parse_certifications_text_to_list(text) do
    text
    |> String.split(["\n", ";", "•"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&format_certification_entry/1)
  end

  defp create_sections_from_resume_data(portfolio, parsed_data, section_selections) do
    existing_sections = Portfolios.list_portfolio_sections(portfolio.id)
    max_position = case existing_sections do
      [] -> 0
      sections -> Enum.map(sections, & &1.position) |> Enum.max()
    end

    Logger.info("🔍 SECTIONS: Starting position: #{max_position + 1}")

    section_results = Enum.reduce(section_selections, {:ok, [], max_position}, fn
      {section_type, "true"}, {:ok, acc, position} ->
        Logger.info("🔍 SECTIONS: Processing section type: #{section_type}")

        case create_portfolio_section_from_resume(portfolio, section_type, parsed_data, position + 1) do
          {:ok, section} ->
            Logger.info("🔍 SECTIONS: ✅ Successfully processed: #{section.title}")
            {:ok, [section | acc], position + 1}
          {:error, reason} ->
            Logger.error("🔍 SECTIONS: ❌ Failed: #{inspect(reason)}")
            {:error, reason}
        end

      {section_type, _value}, {:ok, acc, position} ->
        Logger.info("🔍 SECTIONS: Skipping #{section_type}")
        {:ok, acc, position}

      {_section_type, _value}, {:error, reason} ->
        {:error, reason}
    end)

    case section_results do
      {:ok, sections, _final_position} ->
        Logger.info("🔍 SECTIONS: Final success: #{length(sections)} sections processed")
        {:ok, Enum.reverse(sections)}
      {:error, reason} ->
        Logger.error("🔍 SECTIONS: Final error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_portfolio_section_from_resume(portfolio, section_type, parsed_data, position) do
    {portfolio_section_type, section_title, content} = map_resume_section_to_portfolio(section_type, parsed_data)

    # UTF-8 sanitize the content before database operations
    sanitized_content = sanitize_utf8_for_database(content)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: sanitize_utf8_for_database(section_title),
      section_type: portfolio_section_type,
      content: sanitized_content,
      position: position,
      visible: true
    }

    Logger.info("🔍 CREATE: Creating #{portfolio_section_type} section")

    case Portfolios.create_section(section_attrs) do
      {:ok, section} ->
        Logger.info("🔍 CREATE: ✅ Section created successfully with ID: #{section.id}")
        {:ok, section}
      {:error, changeset} ->
        Logger.error("🔍 CREATE: ❌ Section creation failed: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp map_resume_section_to_portfolio(section_type, parsed_data) do
    case section_type do
      "personal_info" ->
        # FIX: Get from the actual parsed data structure
        personal_info = Map.get(parsed_data, :personal_info, %{})
        {:contact, "Contact Information", %{
          "email" => sanitize_utf8_for_database(Map.get(personal_info, "email", "")),
          "phone" => sanitize_utf8_for_database(Map.get(personal_info, "phone", "")),
          "location" => sanitize_utf8_for_database(Map.get(personal_info, "location", "")),
          "name" => sanitize_utf8_for_database(Map.get(personal_info, "name", "")),
          "website" => sanitize_utf8_for_database(Map.get(personal_info, "website", "")),
          "linkedin" => sanitize_utf8_for_database(Map.get(personal_info, "linkedin", "")),
          "github" => sanitize_utf8_for_database(Map.get(personal_info, "github", ""))
        }}

      "professional_summary" ->
        # FIX: Get from the actual parsed data structure
        summary = Map.get(parsed_data, :professional_summary, "")
        personal_info = Map.get(parsed_data, :personal_info, %{})
        {:intro, "Professional Summary", %{
          "headline" => sanitize_utf8_for_database(Map.get(personal_info, "name", "Professional Summary")),
          "summary" => sanitize_utf8_for_database(summary),
          "location" => sanitize_utf8_for_database(Map.get(personal_info, "location", ""))
        }}

      "work_experience" ->
        # FIX: Get from the actual parsed data structure
        work_exp = Map.get(parsed_data, :work_experience, [])
        {:experience, "Work Experience", %{
          "jobs" => work_exp
        }}

      "skills" ->
        # FIX: Get from the actual parsed data structure
        skills = Map.get(parsed_data, :skills, [])
        {:skills, "Skills & Expertise", %{
          "skills" => skills
        }}

      "education" ->
        # FIXED: Proper education section mapping with all required fields
        education_data = Map.get(parsed_data, :education, [])
        Logger.info("🔍 EDUCATION MAPPING: Education data: #{inspect(education_data)}")

        # Ensure education data is properly formatted
        formatted_education = Enum.map(education_data, fn edu ->
          %{
            "degree" => sanitize_utf8_for_database(Map.get(edu, "degree", "")),
            "field" => sanitize_utf8_for_database(Map.get(edu, "field", "")),
            "institution" => sanitize_utf8_for_database(Map.get(edu, "institution", "")),
            "location" => sanitize_utf8_for_database(Map.get(edu, "location", "")),
            "start_date" => sanitize_utf8_for_database(Map.get(edu, "start_date", "")),
            "end_date" => sanitize_utf8_for_database(Map.get(edu, "end_date", "")),
            "status" => sanitize_utf8_for_database(Map.get(edu, "status", "Completed")),
            "gpa" => sanitize_utf8_for_database(Map.get(edu, "gpa", "")),
            "description" => sanitize_utf8_for_database(Map.get(edu, "description", "")),
            "relevant_coursework" => sanitize_utf8_for_database(Map.get(edu, "relevant_coursework", [])),
            "activities" => sanitize_utf8_for_database(Map.get(edu, "activities", []))
          }
        end)

        Logger.info("🔍 EDUCATION MAPPING: Formatted education: #{inspect(formatted_education)}")

        {:education, "Education", %{
          "education" => formatted_education,
          "show_gpa" => true,
          "show_coursework" => true,
          "show_activities" => true
        }}

      "projects" ->
        projects = Map.get(parsed_data, :projects, [])
        {:projects, "Projects", %{
          "projects" => projects
        }}

      "certifications" ->
        certs = Map.get(parsed_data, :certifications, [])
        {:achievements, "Certifications & Achievements", %{
          "achievements" => certs
        }}

      _ ->
        {:custom, format_section_title(section_type), %{
          "title" => sanitize_utf8_for_database(format_section_title(section_type)),
          "content" => sanitize_utf8_for_database(Map.get(parsed_data, section_type, "")),
          "layout" => "default"
        }}
    end
  end

  defp get_parsed_field(parsed_data, field) when is_map(parsed_data) do
    case Map.get(parsed_data, field) do
      nil ->
        # Try with string key if atom key doesn't exist
        string_key = if is_atom(field), do: to_string(field), else: field
        Map.get(parsed_data, string_key)
      value ->
        value
    end
  rescue
    _ -> nil
  end
  defp get_parsed_field(_, _), do: nil

  defp determine_available_sections(raw_data) do
    %{
      "personal_info" => has_content?(extract_safe_utf8(raw_data, "personal_info", %{})),
      "professional_summary" => has_content?(extract_safe_utf8(raw_data, "professional_summary", "")),
      "work_experience" => has_list_content?(extract_safe_utf8(raw_data, "work_experience", [])),
      "education" => has_list_content?(extract_safe_utf8(raw_data, "education", [])),
      "skills" => has_list_content?(extract_safe_utf8(raw_data, "skills", [])),
      "projects" => has_list_content?(extract_safe_utf8(raw_data, "projects", [])),
      "certifications" => has_list_content?(extract_safe_utf8(raw_data, "certifications", []))
    }
  end

  defp assess_content_quality(raw_data) do
    %{
      "personal_info_completeness" => assess_personal_info_quality(extract_safe_utf8(raw_data, "personal_info", %{})),
      "experience_detail_level" => assess_experience_quality(extract_safe_utf8(raw_data, "work_experience", [])),
      "skills_organization" => assess_skills_quality(extract_safe_utf8(raw_data, "skills", [])),
      "overall_parsing_confidence" => 75,  # Default confidence for your original parser
      "parsing_strategy" => "original_parser",
      "sections_found" => count_sections_found(raw_data)
    }
  end

  defp count_sections_found(data) do
    data
    |> Map.keys()
    |> Enum.count(fn key ->
      value = Map.get(data, key)
      case value do
        list when is_list(list) -> length(list) > 0
        string when is_binary(string) -> String.trim(string) != ""
        map when is_map(map) -> map_size(map) > 0
        _ -> false
      end
    end)
  end

  defp assess_personal_info_quality(personal_info) when is_map(personal_info) do
    fields = ["name", "email", "phone", "location"]
    filled_fields = Enum.count(fields, fn field ->
      value = Map.get(personal_info, field, "")
      is_binary(value) && String.trim(value) != ""
    end)

    (filled_fields / length(fields)) * 100
  end
  defp assess_personal_info_quality(_), do: 0

  defp assess_experience_quality(work_experience) when is_list(work_experience) do
    if length(work_experience) == 0 do
      0
    else
      avg_completeness = work_experience
      |> Enum.map(fn job ->
        required_fields = ["title", "company", "description"]
        filled = Enum.count(required_fields, fn field ->
          value = Map.get(job, field, "")
          is_binary(value) && String.length(String.trim(value)) > 5
        end)
        (filled / length(required_fields)) * 100
      end)
      |> Enum.sum()
      |> Kernel./(length(work_experience))

      round(avg_completeness)
    end
  end
  defp assess_experience_quality(_), do: 0

  defp assess_skills_quality(skills) when is_list(skills) do
    cond do
      length(skills) >= 10 -> 90
      length(skills) >= 5 -> 70
      length(skills) >= 3 -> 50
      length(skills) >= 1 -> 30
      true -> 0
    end
  end
  defp assess_skills_quality(_), do: 0

  defp has_content?(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.any?(fn value ->
      case value do
        str when is_binary(str) -> String.trim(str) != ""
        _ -> false
      end
    end)
  end

  defp has_content?(content) when is_binary(content), do: String.trim(content) != ""
  defp has_content?(_), do: false

  # Helper to check if list content exists
  defp has_list_content?(list) when is_list(list), do: length(list) > 0
  defp has_list_content?(_), do: false


  defp format_section_title(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

end
