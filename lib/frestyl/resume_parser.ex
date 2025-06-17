# lib/frestyl/resume_parser.ex - BACK TO BASICS + TARGETED FIXES

defmodule Frestyl.ResumeParser do
  @moduledoc """
  Enhanced resume parsing with AI integration, multiple file format support,
  and advanced skills proficiency detection.
  """

  require Logger

  @supported_formats ~w(.pdf .doc .docx .txt .rtf)
  @max_file_size 10 * 1024 * 1024  # 10MB

  @doc """
  Parse resume with filename for format detection
  """
  def parse_resume_with_filename(file_path, filename) do
    case validate_file(file_path, filename) do
      :ok ->
        case extract_text_from_file(file_path, filename) do
          {:ok, text} ->
            parse_resume_text(text, filename)
          {:error, reason} ->
            {:error, "Text extraction failed: #{reason}"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Main resume parsing function
  """
  def parse_resume(file_path) do
    case File.exists?(file_path) do
      true ->
        filename = Path.basename(file_path)
        parse_resume_with_filename(file_path, filename)
      false ->
        {:error, "File not found"}
    end
  end

  # Validate file format and size
  defp validate_file(file_path, filename) do
    extension = Path.extname(filename) |> String.downcase()

    cond do
      extension not in @supported_formats ->
        {:error, "Unsupported file format. Supported: #{Enum.join(@supported_formats, ", ")}"}

      File.stat!(file_path).size > @max_file_size ->
        {:error, "File too large. Maximum size: 10MB"}

      true ->
        :ok
    end
  end

  # Extract text from different file formats
  defp extract_text_from_file(file_path, filename) do
    extension = Path.extname(filename) |> String.downcase()

    case extension do
      ".txt" -> File.read(file_path)
      ".pdf" -> extract_from_pdf(file_path)
      ".doc" -> extract_from_doc(file_path)
      ".docx" -> extract_from_docx(file_path)
      ".rtf" -> extract_from_rtf(file_path)
      _ -> {:error, "Unsupported format"}
    end
  end

  # PDF extraction with multiple methods
  defp extract_from_pdf(file_path) do
    IO.puts("🔍 PDF DEBUG: Starting enhanced PDF extraction")

    # Try Method 1: pdftotext (fastest)
    case System.cmd("pdftotext", [file_path, "-"], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 100 ->
        IO.puts("🔍 PDF DEBUG: pdftotext successful, length: #{byte_size(text)}")
        {:ok, clean_extracted_text(text)}

      {_, _} ->
        # Try Method 2: pdfplumber (better for complex layouts)
        case extract_pdf_with_pdfplumber(file_path) do
          {:ok, text} when byte_size(text) > 100 ->
            IO.puts("🔍 PDF DEBUG: pdfplumber successful")
            {:ok, text}

          {:error, _} ->
            # Fallback to PyPDF2
            extract_pdf_with_pypdf2(file_path)
        end
    end
  rescue
    _ ->
      extract_pdf_with_pdfplumber(file_path)
  end

  defp extract_pdf_with_pdfplumber(file_path) do
    python_script = """
    import pdfplumber
    import sys

    try:
        text = ''
        with pdfplumber.open('#{file_path}') as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + '\\n'

        print(text)

    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}")
        sys.exit(1)
    """

    case System.cmd("python3", ["-c", python_script], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 50 ->
        {:ok, clean_extracted_text(text)}

      {error_output, _} ->
        {:error, "pdfplumber failed: #{error_output}"}
    end
  rescue
    error ->
      {:error, "pdfplumber exception: #{Exception.message(error)}"}
  end

  defp extract_pdf_with_pypdf2(file_path) do
    python_script = """
    import PyPDF2
    import sys

    try:
        with open('#{file_path}', 'rb') as file:
            reader = PyPDF2.PdfReader(file)
            text = ''
            for page in reader.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + '\\n'

        print(text)

    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}")
        sys.exit(1)
    """

    case System.cmd("python3", ["-c", python_script], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 50 ->
        {:ok, clean_extracted_text(text)}

      {error_output, _} ->
        {:error, "PyPDF2 failed: #{error_output}"}
    end
  rescue
    error ->
      {:error, "PyPDF2 exception: #{Exception.message(error)}"}
  end

  # DOCX extraction with multiple methods
  defp extract_from_docx(file_path) do
    IO.puts("🔍 DOCX DEBUG: Starting enhanced DOCX extraction for: #{file_path}")

    # Try Method 1: python-docx (most reliable)
    case extract_docx_with_python_docx(file_path) do
      {:ok, text} when byte_size(text) > 100 ->
        IO.puts("🔍 DOCX DEBUG: python-docx successful, length: #{byte_size(text)}")
        {:ok, text}

      {:error, reason} ->
        IO.puts("🔍 DOCX DEBUG: python-docx failed: #{reason}")

        # Try Method 2: mammoth (handles complex formatting better)
        case extract_docx_with_mammoth(file_path) do
          {:ok, text} when byte_size(text) > 100 ->
            IO.puts("🔍 DOCX DEBUG: mammoth successful, length: #{byte_size(text)}")
            {:ok, text}

          {:error, reason2} ->
            IO.puts("🔍 DOCX DEBUG: mammoth failed: #{reason2}")

            # Fallback to manual XML extraction
            extract_docx_manual_enhanced(file_path)
        end
    end
  end

  # Method 1: python-docx (most common)
  defp extract_docx_with_python_docx(file_path) do
    python_script = """
    from docx import Document
    import sys

    try:
        doc = Document('#{file_path}')
        text = ''

        # Extract paragraphs
        for paragraph in doc.paragraphs:
            if paragraph.text.strip():
                text += paragraph.text + '\\n'

        # Extract tables
        for table in doc.tables:
            for row in table.rows:
                for cell in row.cells:
                    if cell.text.strip():
                        text += cell.text + ' '
                text += '\\n'

        # Extract headers and footers
        for section in doc.sections:
            if section.header:
                for paragraph in section.header.paragraphs:
                    if paragraph.text.strip():
                        text += paragraph.text + '\\n'
            if section.footer:
                for paragraph in section.footer.paragraphs:
                    if paragraph.text.strip():
                        text += paragraph.text + '\\n'

        print(text)

    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}")
        sys.exit(1)
    """

    case System.cmd("python3", ["-c", python_script], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 50 ->
        cleaned_text = clean_extracted_text(text)
        IO.puts("🔍 DOCX DEBUG: python-docx extracted #{String.length(cleaned_text)} characters")
        {:ok, cleaned_text}

      {error_output, _} ->
        {:error, "python-docx failed: #{error_output}"}
    end
  rescue
    error ->
      {:error, "python-docx exception: #{Exception.message(error)}"}
  end

  # Method 2: mammoth (better formatting preservation)
  defp extract_docx_with_mammoth(file_path) do
    python_script = """
    import mammoth
    import sys

    try:
        with open('#{file_path}', 'rb') as docx_file:
            result = mammoth.extract_raw_text(docx_file)
            print(result.value)

    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}")
        sys.exit(1)
    """

    case System.cmd("python3", ["-c", python_script], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 50 ->
        cleaned_text = clean_extracted_text(text)
        IO.puts("🔍 DOCX DEBUG: mammoth extracted #{String.length(cleaned_text)} characters")
        {:ok, cleaned_text}

      {error_output, _} ->
        {:error, "mammoth failed: #{error_output}"}
    end
  rescue
    error ->
      {:error, "mammoth exception: #{Exception.message(error)}"}
  end

  # Enhanced manual extraction with better XML parsing
  defp extract_docx_manual_enhanced(file_path) do
    IO.puts("🔍 DOCX DEBUG: Trying enhanced manual DOCX extraction")

    case System.cmd("unzip", ["-p", file_path, "word/document.xml"], stderr_to_stdout: true) do
      {xml_content, 0} when byte_size(xml_content) > 100 ->
        IO.puts("🔍 DOCX DEBUG: Unzip successful, XML length: #{byte_size(xml_content)}")

        # More sophisticated XML parsing
        text = xml_content
               |> String.replace(~r/<w:br[^>]*>/i, "\n")           # Convert breaks to newlines
               |> String.replace(~r/<w:p[^>]*>/i, "\n")            # Convert paragraphs to newlines
               |> String.replace(~r/<w:tab[^>]*>/i, " ")           # Convert tabs to spaces
               |> String.replace(~r/<[^>]+>/, " ")                 # Remove all other XML tags
               |> String.replace(~r/\s+/, " ")                     # Normalize whitespace
               |> String.replace(~r/\n\s*\n/, "\n")               # Remove extra line breaks
               |> String.trim()

        IO.puts("🔍 DOCX DEBUG: Enhanced manual extraction result length: #{String.length(text)}")

        if String.length(text) > 50 do
          {:ok, text}
        else
          {:error, "Extracted text too short"}
        end

      {error_output, _} ->
        IO.puts("🔍 DOCX DEBUG: Unzip failed: #{error_output}")
        {:error, "Could not extract DOCX content"}
    end
  rescue
    error ->
      IO.puts("🔍 DOCX DEBUG: Manual extraction exception: #{Exception.message(error)}")
      {:error, "Enhanced manual DOCX extraction failed"}
  end

  # DOC file extraction
  defp extract_from_doc(file_path) do
    IO.puts("🔍 DOC DEBUG: Starting DOC extraction")

    # Try antiword for .doc files
    case System.cmd("antiword", [file_path], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 0 ->
        IO.puts("🔍 DOC DEBUG: antiword successful, length: #{byte_size(text)}")
        {:ok, clean_extracted_text(text)}

      {_, _} ->
        {:error, "Could not extract DOC content. Please convert to DOCX or PDF."}
    end
  rescue
    _ ->
      {:error, "DOC extraction not available. Please convert to DOCX or PDF."}
  end

  # RTF file extraction
  defp extract_from_rtf(file_path) do
    IO.puts("🔍 RTF DEBUG: Starting RTF extraction")

    # Basic RTF parsing - strip RTF control codes
    case File.read(file_path) do
      {:ok, content} ->
        text = content
               |> String.replace(~r/\\[a-z]+\d*\s?/, " ")  # Remove RTF control words
               |> String.replace(~r/[{}]/, " ")            # Remove braces
               |> String.replace(~r/\s+/, " ")             # Normalize whitespace
               |> String.trim()

        IO.puts("🔍 RTF DEBUG: Extracted #{String.length(text)} characters")
        {:ok, text}

      {:error, reason} ->
        {:error, "RTF read failed: #{reason}"}
    end
  end

  defp clean_extracted_text(text) do
    text
    |> String.replace(~r/\r\n/, "\n")     # Normalize line endings
    |> String.replace(~r/\r/, "\n")       # Mac line endings
    |> String.replace(~r/\n{3,}/, "\n\n") # Reduce excessive line breaks
    |> String.replace(~r/[ \t]+/, " ")    # Normalize whitespace
    |> String.trim()
  end

  # MAIN PARSING FUNCTION - ADD DEBUG BUT KEEP SIMPLE
  defp parse_resume_text(text, filename) do
    IO.puts("🔍 PARSER DEBUG: ===== RESUME PARSING STARTED =====")
    IO.puts("🔍 PARSER DEBUG: Filename: #{filename}")
    IO.puts("🔍 PARSER DEBUG: Raw text length: #{String.length(text)} characters")

    # DEBUG: Show actual text structure
    lines = String.split(text, "\n", trim: true)
    IO.puts("🔍 PARSER DEBUG: Found #{length(lines)} lines")
    IO.puts("🔍 PARSER DEBUG: First 20 lines:")
    lines |> Enum.take(20) |> Enum.with_index() |> Enum.each(fn {line, idx} ->
      IO.puts("🔍 #{idx}: #{line}")
    end)

    try do
      # SIMPLE parsing - back to basics
      parsed_data = %{
        "filename" => filename,
        "raw_text" => text,
        "personal_info" => extract_personal_info(text),
        "professional_summary" => extract_professional_summary(text),
        "work_experience" => extract_work_experience_simple(text),
        "education" => extract_education_simple(text),
        "skills" => extract_skills_simple(text),
        "projects" => extract_projects_simple(text),
        "certifications" => extract_certifications_simple(text),
        "achievements" => extract_achievements_simple(text),
        "languages" => extract_languages_simple(text)
      }

      # Add enhanced skills
      enhanced_skills = process_skills_with_ai_detection(parsed_data["skills"], text, parsed_data["work_experience"])
      parsed_data = Map.put(parsed_data, "skills", enhanced_skills)

      IO.puts("🔍 PARSER DEBUG: ===== PARSING RESULTS =====")
      IO.puts("🔍 PARSER DEBUG: Personal Info: #{inspect(parsed_data["personal_info"])}")
      IO.puts("🔍 PARSER DEBUG: Enhanced Skills count: #{length(enhanced_skills)}")
      IO.puts("🔍 PARSER DEBUG: Work Experience entries: #{length(parsed_data["work_experience"])}")
      IO.puts("🔍 PARSER DEBUG: Education entries: #{length(parsed_data["education"])}")

      {:ok, parsed_data}
    rescue
      error ->
        Logger.error("Resume parsing failed: #{Exception.message(error)}")
        {:error, "Failed to parse resume content: #{Exception.message(error)}"}
    end
  end

  # BACK TO BASICS - SIMPLE EXTRACTION FUNCTIONS

  # Simple work experience extraction
  defp extract_work_experience_simple(text) do
    IO.puts("🔍 EXPERIENCE SIMPLE: Starting simple work experience extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for "EXPERIENCE" or "WORK" section header
    experience_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["experience", "work experience", "professional experience", "employment", "work"] ||
      String.contains?(line_clean, "experience") && String.length(line_clean) < 30
    end)

    if experience_start do
      IO.puts("🔍 EXPERIENCE SIMPLE: Found experience section at line #{experience_start}: '#{Enum.at(lines, experience_start)}'")

      # Get next section start
      next_section = Enum.drop(lines, experience_start + 1)
      |> Enum.find_index(fn line ->
        line_clean = String.trim(line) |> String.downcase()
        line_clean in ["education", "skills", "projects", "certifications", "awards"] ||
        (String.length(line_clean) < 30 && String.match?(line_clean, ~r/^[a-z\s]+$/))
      end)

      end_index = if next_section, do: experience_start + next_section + 1, else: length(lines)

      experience_lines = Enum.slice(lines, (experience_start + 1)..(end_index - 1))
      experience_text = Enum.join(experience_lines, "\n")

      IO.puts("🔍 EXPERIENCE SIMPLE: Extracted #{length(experience_lines)} lines of experience")
      IO.puts("🔍 EXPERIENCE SIMPLE: Content preview: #{String.slice(experience_text, 0, 200)}...")

      if String.length(experience_text) > 50 do
        parse_simple_jobs(experience_text)
      else
        []
      end
    else
      IO.puts("🔍 EXPERIENCE SIMPLE: No experience section found")
      []
    end
  end

  # Simple education extraction
  defp extract_education_simple(text) do
    IO.puts("🔍 EDUCATION SIMPLE: Starting simple education extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for "EDUCATION" section header
    education_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["education", "academic background", "qualifications"] ||
      String.contains?(line_clean, "education") && String.length(line_clean) < 30
    end)

    if education_start do
      IO.puts("🔍 EDUCATION SIMPLE: Found education section at line #{education_start}: '#{Enum.at(lines, education_start)}'")

      # Get next section start
      next_section = Enum.drop(lines, education_start + 1)
      |> Enum.find_index(fn line ->
        line_clean = String.trim(line) |> String.downcase()
        line_clean in ["experience", "skills", "projects", "certifications", "awards"] ||
        (String.length(line_clean) < 30 && String.match?(line_clean, ~r/^[a-z\s]+$/))
      end)

      end_index = if next_section, do: education_start + next_section + 1, else: length(lines)

      education_lines = Enum.slice(lines, (education_start + 1)..(end_index - 1))
      education_text = Enum.join(education_lines, "\n")

      IO.puts("🔍 EDUCATION SIMPLE: Extracted #{length(education_lines)} lines of education")
      IO.puts("🔍 EDUCATION SIMPLE: Content preview: #{String.slice(education_text, 0, 200)}...")

      if String.length(education_text) > 20 do
        parse_simple_education(education_text)
      else
        []
      end
    else
      IO.puts("🔍 EDUCATION SIMPLE: No education section found")
      []
    end
  end

  # Simple skills extraction
  defp extract_skills_simple(text) do
    IO.puts("🔍 SKILLS SIMPLE: Starting simple skills extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for "SKILLS" section header
    skills_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["skills", "technical skills", "core competencies", "expertise"] ||
      String.contains?(line_clean, "skills") && String.length(line_clean) < 30
    end)

    if skills_start do
      IO.puts("🔍 SKILLS SIMPLE: Found skills section at line #{skills_start}: '#{Enum.at(lines, skills_start)}'")

      # Get next section start
      next_section = Enum.drop(lines, skills_start + 1)
      |> Enum.find_index(fn line ->
        line_clean = String.trim(line) |> String.downcase()
        line_clean in ["experience", "education", "projects", "certifications", "awards"] ||
        (String.length(line_clean) < 30 && String.match?(line_clean, ~r/^[a-z\s]+$/))
      end)

      end_index = if next_section, do: skills_start + next_section + 1, else: length(lines)

      skills_lines = Enum.slice(lines, (skills_start + 1)..(end_index - 1))
      skills_text = Enum.join(skills_lines, " ")

      IO.puts("🔍 SKILLS SIMPLE: Extracted #{length(skills_lines)} lines of skills")
      IO.puts("🔍 SKILLS SIMPLE: Content: #{skills_text}")

      if String.length(skills_text) > 10 do
        parse_simple_skills(skills_text)
      else
        []
      end
    else
      IO.puts("🔍 SKILLS SIMPLE: No skills section found")
      []
    end
  end

  # ADD THESE NEW FUNCTIONS TO YOUR EXISTING resume_parser.ex

  defp parse_simple_jobs(experience_text) do
    Logger.info("🔍 JOBS_SIMPLE: Parsing jobs from text")

    # Clean UTF-8 encoding issues
    cleaned_text = experience_text
    |> String.replace(~r/[^\x00-\x7F]/u, " ")  # Replace non-ASCII chars
    |> String.replace(~r/\s+/, " ")            # Normalize whitespace

    # Look for pipe-separated format: "Company | Title | Date"
    pipe_jobs = Regex.scan(~r/([A-Za-z][^|\n]*?)\s*\|\s*([^|\n]+?)\s*\|\s*([^|\n]+)/i, cleaned_text)

    if length(pipe_jobs) > 0 do
      Logger.info("🔍 JOBS_SIMPLE: Found #{length(pipe_jobs)} pipe-separated jobs")

      Enum.map(pipe_jobs, fn [_, company, title, date_range] ->
        # Clean the date range
        clean_date = String.replace(date_range, ~r/[^\x00-\x7F]/u, " ") |> String.trim()
        current = String.contains?(String.downcase(clean_date), ["current", "present"])

        %{
          "company" => String.trim(company),
          "title" => String.trim(title),
          "start_date" => extract_start_date_clean(clean_date),
          "end_date" => extract_end_date_clean(clean_date),
          "current" => current,
          "description" => String.replace(cleaned_text, ~r/[^\x00-\x7F]/u, " ") |> String.slice(0, 500),
          "responsibilities" => [],
          "achievements" => [],
          "technologies" => []
        }
      end)
    else
      # Fallback logic stays the same
      Logger.info("🔍 JOBS_SIMPLE: No pipe pattern found, creating single job")

      [%{
        "company" => "Professional Experience",
        "title" => "Role",
        "start_date" => "",
        "end_date" => "",
        "current" => false,
        "description" => String.replace(cleaned_text, ~r/[^\x00-\x7F]/u, " ") |> String.slice(0, 800),
        "responsibilities" => [],
        "achievements" => [],
        "technologies" => []
      }]
    end
  end

  defp extract_start_date_clean(date_range) do
    case String.split(date_range, ~r/\s*[-–—]\s*|to\s+/i, parts: 2) do
      [start, _] -> String.trim(start)
      [single] -> String.trim(single)
      _ -> ""
    end
  end

  defp extract_end_date_clean(date_range) do
    if String.contains?(String.downcase(date_range), ["current", "present"]) do
      ""
    else
      case String.split(date_range, ~r/\s*[-–—]\s*|to\s+/i, parts: 2) do
        [_, end_date] -> String.trim(end_date)
        _ -> ""
      end
    end
  end

  defp extract_jobs_from_experience_text(text) do
    # Look for the pattern we see in your resume: "Company | Title | Date"
    pipe_jobs = Regex.scan(~r/([A-Za-z][^|\n]*?)\s*\|\s*([^|\n]+?)\s*\|\s*([^|\n]+)/i, text)
    |> Enum.map(fn [_, company, title, date_range] ->
      create_job_entry(String.trim(company), String.trim(title), String.trim(date_range), text)
    end)

    if length(pipe_jobs) > 0 do
      pipe_jobs
    else
      # Try "Title at Company" pattern
      at_jobs = Regex.scan(~r/([^(\n]+?)\s+at\s+([^(\n]+?)(?:\s*\(([^)]+)\))?/i, text)
      |> Enum.map(fn matches ->
        case matches do
          [_, title, company, date_range] ->
            create_job_entry(String.trim(company), String.trim(title), String.trim(date_range || ""), text)
          [_, title, company] ->
            create_job_entry(String.trim(company), String.trim(title), "", text)
        end
      end)

      at_jobs
    end
  end

  defp create_job_entry(company, title, date_range, full_text) do
    {start_date, end_date, current} = parse_date_range(date_range)

    %{
      "company" => company,
      "title" => title,
      "start_date" => start_date,
      "end_date" => end_date,
      "current" => current,
      "description" => extract_job_description(company, title, full_text),
      "responsibilities" => extract_responsibilities_from_text(full_text),
      "achievements" => [],
      "technologies" => []
    }
  end

  defp parse_date_range(date_range) do
    cleaned = String.downcase(String.trim(date_range))

    cond do
      String.contains?(cleaned, "current") || String.contains?(cleaned, "present") ->
        start_date = String.replace(cleaned, ~r/\s*[-–—]\s*(current|present).*$/i, "") |> String.trim()
        {start_date, "", true}

      String.contains?(cleaned, "–") || String.contains?(cleaned, "-") || String.contains?(cleaned, "to") ->
        parts = String.split(cleaned, ~r/\s*[-–—]\s*|to\s+/i, parts: 2)
        case parts do
          [start_part, end_part] -> {String.trim(start_part), String.trim(end_part), false}
          [single_part] -> {String.trim(single_part), "", false}
        end

      true ->
        {String.trim(cleaned), "", false}
    end
  end

  defp extract_job_description(company, title, full_text) do
    # Simplified approach - just take a portion of the text
    String.slice(full_text, 0, 500)
  end

  defp extract_responsibilities_from_text(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, "•"))
    |> Enum.map(&String.replace(&1, ~r/^•\s*/, ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(10)  # Limit to 10 responsibilities
  end

  defp has_real_job_data?(jobs) do
    Enum.any?(jobs, fn job ->
      company = Map.get(job, "company", "")
      title = Map.get(job, "title", "")

      # Check if we have real data (not generic placeholders)
      company != "Company" &&
      company != "" &&
      title != "Position" &&
      title != "Experience Entry" &&
      String.length(company) > 3 &&
      String.length(title) > 3
    end)
  end

  defp create_enhanced_fallback_job(text) do
    # Try to extract any company name or meaningful title from the text
    lines = String.split(text, "\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    # Look for potential company names (lines with Inc, Corp, LLC, etc.)
    potential_company = Enum.find(lines, fn line ->
      String.contains?(String.downcase(line), ["inc", "corp", "llc", "company", "ltd"]) &&
      String.length(line) < 100
    end)

    # Look for potential job titles (lines with job-related words)
    potential_title = Enum.find(lines, fn line ->
      String.contains?(String.downcase(line), ["engineer", "manager", "developer", "analyst", "consultant", "specialist", "coordinator", "director", "lead"]) &&
      String.length(line) < 100
    end)

    %{
      "company" => potential_company || "Professional Experience",
      "title" => potential_title || "Professional Role",
      "start_date" => "",
      "end_date" => "",
      "current" => false,
      "description" => String.slice(text, 0, 800),
      "responsibilities" => extract_responsibilities_from_text(text),
      "achievements" => [],
      "technologies" => []
    }
  end

  defp parse_simple_education(education_text) do
    # Very basic education parsing
    if String.length(education_text) > 20 do
      [%{
        "institution" => "Institution",
        "degree" => "Degree",
        "field" => "",
        "start_date" => "",
        "end_date" => "",
        "gpa" => "",
        "description" => String.slice(education_text, 0, 200)
      }]
    else
      []
    end
  end

  defp parse_simple_skills(skills_text) do
    # Simple skill parsing - split by common separators
    skills_text
    |> String.split(~r/[,;•\|\n]/)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn skill ->
      String.length(skill) > 2 && String.length(skill) < 50 &&
      !Regex.match?(~r/^\d+$/, skill)
    end)
    |> Enum.take(50)  # Limit to 50 skills
  end

  # Keep all the other simple extraction functions basic
  defp extract_projects_simple(_text), do: []
  defp extract_certifications_simple(_text), do: []
  defp extract_achievements_simple(_text), do: ""
  defp extract_languages_simple(_text), do: ""

  # Keep all the personal info and summary extraction as they were working
  defp extract_personal_info(text) do
    %{
      "name" => extract_name(text),
      "email" => extract_email(text),
      "phone" => extract_phone(text),
      "location" => extract_location(text),
      "linkedin" => extract_linkedin(text),
      "github" => extract_github(text),
      "website" => extract_website(text)
    }
  end

  defp extract_name(text) do
    lines = String.split(text, "\n", trim: true)
    candidates = lines
      |> Enum.take(5)
      |> Enum.filter(&(String.length(&1) > 2 && String.length(&1) < 100))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Look for lines that look like names
    name = candidates
      |> Enum.find(fn line ->
        words = String.split(line, " ", trim: true)
        length(words) >= 2 && length(words) <= 4 &&
        Enum.all?(words, &String.match?(&1, ~r/^[A-Z][a-z]+$/)) &&
        !String.contains?(String.downcase(line), ["email", "phone", "resume", "cv"])
      end)

    name || ""
  end

  defp extract_email(text) do
    case Regex.run(~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, text) do
      [email] -> email
      _ -> ""
    end
  end

  defp extract_phone(text) do
    patterns = [
      ~r/\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/,
      ~r/\+1[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/
    ]

    Enum.find_value(patterns, "", fn pattern ->
      case Regex.run(pattern, text) do
        [phone] -> String.trim(phone)
        _ -> nil
      end
    end)
  end

  defp extract_location(text) do
    location_patterns = [
      ~r/([A-Z][a-z]+,\s*[A-Z]{2})/,
      ~r/([A-Z][a-z]+\s+[A-Z][a-z]+,\s*[A-Z]{2})/
    ]

    Enum.find_value(location_patterns, "", fn pattern ->
      case Regex.run(pattern, text) do
        [_, location] -> String.trim(location)
        _ -> nil
      end
    end)
  end

  defp extract_linkedin(text) do
    case Regex.run(~r/linkedin\.com\/in\/[\w-]+/, text) do
      [linkedin] -> "https://" <> linkedin
      _ -> ""
    end
  end

  defp extract_github(text) do
    case Regex.run(~r/github\.com\/[\w-]+/, text) do
      [github] -> "https://" <> github
      _ -> ""
    end
  end

  defp extract_website(text) do
    case Regex.run(~r/https?:\/\/[^\s]+\.[^\s]+/, text) do
      [website] -> String.trim(website, ".,")
      _ -> ""
    end
  end

  defp extract_professional_summary(text) do
    lines = String.split(text, "\n", trim: true)
    summary_indicators = ["summary", "objective", "profile", "about"]

    # Find explicit summary section
    summary = Enum.find_value(lines, fn line ->
      if Enum.any?(summary_indicators, &String.contains?(String.downcase(line), &1)) do
        index = Enum.find_index(lines, &(&1 == line))
        if index do
          content = lines
          |> Enum.drop(index + 1)
          |> Enum.take_while(fn next_line ->
            # Continue until we hit another section header
            !(String.length(String.trim(next_line)) < 30 &&
              String.downcase(String.trim(next_line)) in ["experience", "education", "skills", "projects"])
          end)
          |> Enum.take(5)
          |> Enum.join(" ")
          |> String.trim()

          if String.length(content) > 20, do: content, else: nil
        end
      end
    end)

    # If no explicit summary, look for a paragraph that seems like one
    summary || Enum.find_value(lines, fn line ->
      if String.length(line) > 100 &&
         String.contains?(String.downcase(line), ["professional", "experience", "years"]) do
        line
      end
    end) || ""
  end

  # Keep the enhanced skills processing
  defp process_skills_with_ai_detection(basic_skills, full_text, work_experience) do
    IO.puts("🔍 SKILLS AI: Processing #{length(basic_skills)} skills with AI detection")

    basic_skills
    |> Enum.map(fn skill_name ->
      proficiency = detect_skill_proficiency(skill_name, full_text)
      years = calculate_skill_years(skill_name, work_experience, full_text)
      category = auto_categorize_skill(skill_name)

      %{
        "name" => skill_name,
        "proficiency" => proficiency,
        "years" => years,
        "category" => category,
        "color_intensity" => get_color_intensity(proficiency),
        "display_priority" => get_display_priority(proficiency, years)
      }
    end)
    |> Enum.sort_by(fn skill -> -skill["display_priority"] end)
  end

  defp detect_skill_proficiency(skill_name, text) do
    skill_lower = String.downcase(skill_name)
    text_lower = String.downcase(text)

    # Look for explicit proficiency mentions
    proficiency_patterns = [
      {~r/expert\s+(?:in\s+|with\s+|at\s+)?#{Regex.escape(skill_lower)}/i, "expert"},
      {~r/#{Regex.escape(skill_lower)}\s+expert/i, "expert"},
      {~r/advanced\s+#{Regex.escape(skill_lower)}/i, "advanced"},
      {~r/proficient\s+(?:in\s+|with\s+)?#{Regex.escape(skill_lower)}/i, "advanced"},
      {~r/experienced\s+(?:in\s+|with\s+)?#{Regex.escape(skill_lower)}/i, "intermediate"},
      {~r/familiar\s+(?:with\s+)?#{Regex.escape(skill_lower)}/i, "beginner"}
    ]

    # Check each pattern
    Enum.find_value(proficiency_patterns, fn {pattern, level} ->
      if Regex.match?(pattern, text_lower), do: level, else: nil
    end) || "intermediate"  # Default
  end

  defp calculate_skill_years(skill_name, work_experience, full_text) when is_list(work_experience) do
    skill_lower = String.downcase(skill_name)

    # First try to extract from explicit mentions
    explicit_years = case Regex.run(~r/(\d+)\s*(?:\+)?\s*years?\s+(?:of\s+)?(?:experience\s+)?(?:with\s+|in\s+|using\s+)?#{Regex.escape(skill_lower)}/i, String.downcase(full_text)) do
      [_, years_str] -> String.to_integer(years_str)
      _ -> 0
    end

    if explicit_years > 0 do
      explicit_years
    else
      # Calculate from work history
      work_experience
      |> Enum.reduce(0, fn job, acc ->
        job_text = [
          Map.get(job, "description", ""),
          Map.get(job, "title", ""),
          Map.get(job, "responsibilities", []) |> Enum.join(" "),
          Map.get(job, "technologies", []) |> Enum.join(" ")
        ]
        |> Enum.join(" ")
        |> String.downcase()

        if String.contains?(job_text, skill_lower) do
          years = 1  # Default to 1 year per job if we can't calculate dates
          acc + years
        else
          acc
        end
      end)
      |> min(15)  # Cap at 15 years
    end
  end
  defp calculate_skill_years(_skill_name, _work_experience, _full_text), do: 0

  defp auto_categorize_skill(skill_name) do
    skill_lower = String.downcase(skill_name)

    cond do
      # Programming Languages
      skill_lower in ["javascript", "python", "java", "c++", "c#", "ruby", "go", "rust", "swift", "kotlin", "php", "typescript", "scala", "r", "matlab", "sql", "c", "objective-c", "dart", "elixir"] ->
        "Programming Languages"

      # Frameworks & Libraries
      skill_lower in ["react", "vue", "angular", "node.js", "express", "django", "flask", "spring", "laravel", "rails", "next.js", "gatsby", "nuxt", "svelte"] ->
        "Frameworks & Libraries"

      # Tools & Platforms
      skill_lower in ["git", "docker", "kubernetes", "aws", "azure", "gcp", "jenkins", "gitlab", "github", "npm", "webpack", "babel", "eslint", "jest", "cypress"] ->
        "Tools & Platforms"

      # Databases
      skill_lower in ["mysql", "postgresql", "mongodb", "redis", "elasticsearch", "sqlite", "oracle", "sql server", "dynamodb", "firebase"] ->
        "Databases"

      # Design & Creative
      skill_lower in ["photoshop", "illustrator", "figma", "sketch", "adobe xd", "canva", "ui design", "ux design", "graphic design", "web design"] ->
        "Design & Creative"

      # Soft Skills
      skill_lower in ["leadership", "communication", "teamwork", "project management", "time management", "problem solving", "critical thinking", "presentation"] ->
        "Soft Skills"

      # Data & Analytics
      skill_lower in ["excel", "tableau", "power bi", "analytics", "data analysis", "statistics", "machine learning", "ai", "data science"] ->
        "Data & Analytics"

      # Default category
      true ->
        "Other"
    end
  end

  defp get_color_intensity(proficiency) do
    case String.downcase(proficiency) do
      "expert" -> "dark"
      "advanced" -> "medium"
      "intermediate" -> "light"
      "beginner" -> "lightest"
      _ -> "light"
    end
  end

  defp get_display_priority(proficiency, years) do
    base_score = case String.downcase(proficiency) do
      "expert" -> 100
      "advanced" -> 75
      "intermediate" -> 50
      "beginner" -> 25
      _ -> 40
    end

    years_bonus = min(years * 5, 25)
    base_score + years_bonus
  end
end
