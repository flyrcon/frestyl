# lib/frestyl/resume_parser.ex - PART 1 OF 3: Module Setup & File Extraction

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

# PART 2 OF 3: Main Parsing Logic & Work Experience

  # 🔥 ENHANCED: Parse resume text with better data structure
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
      # Extract basic sections
      personal_info = extract_personal_info(text)
      professional_summary = extract_professional_summary(text)
      work_experience = extract_work_experience_enhanced(text)
      education = extract_education_enhanced(text)
      basic_skills = extract_skills_enhanced(text)
      projects = extract_projects_enhanced(text)
      certifications = extract_certifications_enhanced(text)

      # 🔥 ENHANCED: Process skills with AI detection to create proper structure
      enhanced_skills_data = process_skills_with_ai_detection(basic_skills, text, work_experience)

      # 🔥 ENHANCED: Create properly structured data
      parsed_data = %{
        "filename" => filename,
        "raw_text" => text,
        "personal_info" => personal_info,
        "professional_summary" => professional_summary,
        "work_experience" => work_experience,
        "education" => education,
        "skills" => enhanced_skills_data["flat_skills"] || basic_skills,
        "skill_categories" => enhanced_skills_data["skill_categories"] || %{},
        "projects" => projects,
        "certifications" => certifications,
        "achievements" => extract_achievements_simple(text),
        "languages" => extract_languages_simple(text),
        "imported_from_resume" => true,
        "parsing_metadata" => %{
          "parsed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "parser_version" => "2.0_enhanced",
          "total_skills_found" => length(basic_skills),
          "categories_created" => map_size(enhanced_skills_data["skill_categories"] || %{})
        }
      }

      IO.puts("🔍 PARSER DEBUG: ===== PARSING RESULTS =====")
      IO.puts("🔍 PARSER DEBUG: Personal Info: #{inspect(parsed_data["personal_info"])}")
      IO.puts("🔍 PARSER DEBUG: Skills categories: #{map_size(parsed_data["skill_categories"])}")
      IO.puts("🔍 PARSER DEBUG: Flat skills count: #{length(parsed_data["skills"])}")
      IO.puts("🔍 PARSER DEBUG: Work Experience entries: #{length(parsed_data["work_experience"])}")
      IO.puts("🔍 PARSER DEBUG: Education entries: #{length(parsed_data["education"])}")

      {:ok, parsed_data}
    rescue
      error ->
        Logger.error("Resume parsing failed: #{Exception.message(error)}")
        {:error, "Failed to parse resume content: #{Exception.message(error)}"}
    end
  end

  # 🔥 ENHANCED: Work experience extraction
  defp extract_work_experience_enhanced(text) do
    IO.puts("🔍 EXPERIENCE ENHANCED: Starting enhanced work experience extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for "EXPERIENCE" or "WORK" section header
    experience_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["experience", "work experience", "professional experience", "employment", "work", "career history"] ||
      (String.contains?(line_clean, "experience") && String.length(line_clean) < 30)
    end)

    if experience_start do
      IO.puts("🔍 EXPERIENCE ENHANCED: Found experience section at line #{experience_start}: '#{Enum.at(lines, experience_start)}'")

      # Get next section start
      next_section = Enum.drop(lines, experience_start + 1)
      |> Enum.find_index(fn line ->
        line_clean = String.trim(line) |> String.downcase()
        line_clean in ["education", "skills", "projects", "certifications", "awards", "achievements"] ||
        (String.length(line_clean) < 30 && String.match?(line_clean, ~r/^[a-z\s]+$/))
      end)

      end_index = if next_section, do: experience_start + next_section + 1, else: length(lines)

      experience_lines = Enum.slice(lines, (experience_start + 1)..(end_index - 1))
      experience_text = Enum.join(experience_lines, "\n")

      IO.puts("🔍 EXPERIENCE ENHANCED: Extracted #{length(experience_lines)} lines of experience")
      IO.puts("🔍 EXPERIENCE ENHANCED: Content preview: #{String.slice(experience_text, 0, 200)}...")

      if String.length(experience_text) > 50 do
        parse_jobs_enhanced(experience_text)
      else
        []
      end
    else
      IO.puts("🔍 EXPERIENCE ENHANCED: No experience section found")
      []
    end
  end

  # 🔥 ENHANCED: Job parsing with better structure
  defp parse_jobs_enhanced(experience_text) do
    IO.puts("🔍 JOBS ENHANCED: Parsing jobs from text")

    # Clean UTF-8 encoding issues
    cleaned_text = experience_text
    |> String.replace(~r/[^\x00-\x7F]/u, " ")  # Replace non-ASCII chars
    |> String.replace(~r/\s+/, " ")            # Normalize whitespace

    # Try multiple parsing strategies
    jobs = try_multiple_job_parsing_strategies(cleaned_text)

    if length(jobs) > 0 do
      IO.puts("🔍 JOBS ENHANCED: Successfully parsed #{length(jobs)} jobs")
      jobs
    else
      IO.puts("🔍 JOBS ENHANCED: No specific jobs found, creating fallback")
      [create_enhanced_fallback_job(cleaned_text)]
    end
  end

  # 🔥 NEW: Try multiple job parsing strategies
  defp try_multiple_job_parsing_strategies(text) do
    strategies = [
      &parse_pipe_separated_jobs/1,
      &parse_company_title_date_jobs/1,
      &parse_title_at_company_jobs/1,
      &parse_structured_bullet_jobs/1
    ]

    Enum.find_value(strategies, [], fn strategy ->
      jobs = strategy.(text)
      if length(jobs) > 0, do: jobs, else: nil
    end) || []
  end

  # 🔥 Strategy 1: Parse "Company | Title | Date" format
  defp parse_pipe_separated_jobs(text) do
    Regex.scan(~r/([A-Za-z][^|\n]*?)\s*\|\s*([^|\n]+?)\s*\|\s*([^|\n]+)/i, text)
    |> Enum.map(fn [_, company, title, date_range] ->
      create_enhanced_job_entry(String.trim(company), String.trim(title), String.trim(date_range), text)
    end)
  end

  # 🔥 Strategy 2: Parse "Company, Title, Date" format
  defp parse_company_title_date_jobs(text) do
    Regex.scan(~r/([A-Z][A-Za-z\s&]+(?:Inc|Corp|LLC|Ltd|Company)?)\s*[,–-]\s*([^,\n]+?)\s*[,–-]\s*([0-9]{4}[^,\n]*)/i, text)
    |> Enum.map(fn [_, company, title, date_range] ->
      create_enhanced_job_entry(String.trim(company), String.trim(title), String.trim(date_range), text)
    end)
  end

  # 🔥 Strategy 3: Parse "Title at Company" format
  defp parse_title_at_company_jobs(text) do
    Regex.scan(~r/([^(\n]+?)\s+at\s+([^(\n]+?)(?:\s*\(([^)]+)\))?/i, text)
    |> Enum.map(fn matches ->
      case matches do
        [_, title, company, date_range] ->
          create_enhanced_job_entry(String.trim(company), String.trim(title), String.trim(date_range || ""), text)
        [_, title, company] ->
          create_enhanced_job_entry(String.trim(company), String.trim(title), "", text)
      end
    end)
  end

  # 🔥 Strategy 4: Parse structured bullet points
  defp parse_structured_bullet_jobs(text) do
    # Look for job blocks separated by clear indicators
    job_blocks = String.split(text, ~r/\n\s*\n/, trim: true)
    |> Enum.filter(fn block -> String.length(block) > 50 end)
    |> Enum.map(&parse_job_block/1)
    |> Enum.reject(&is_nil/1)

    job_blocks
  end

  # 🔥 Parse individual job block
  defp parse_job_block(block) do
    lines = String.split(block, "\n", trim: true)

    # Try to find company, title, and dates from the first few lines
    potential_company = Enum.find(lines, fn line ->
      String.contains?(String.downcase(line), ["inc", "corp", "llc", "ltd", "company"]) ||
      Regex.match?(~r/^[A-Z][A-Za-z\s&]+$/, String.trim(line))
    end)

    potential_title = Enum.find(lines, fn line ->
      title_keywords = ["engineer", "manager", "developer", "analyst", "consultant", "specialist", "coordinator", "director", "lead", "senior"]
      String.contains?(String.downcase(line), title_keywords) && String.length(line) < 100
    end)

    potential_dates = Enum.find(lines, fn line ->
      Regex.match?(~r/\b\d{4}\b.*\b\d{4}\b|\bcurrent\b|\bpresent\b/i, line)
    end)

    if potential_company || potential_title do
      create_enhanced_job_entry(
        potential_company || "Company",
        potential_title || "Professional Role",
        potential_dates || "",
        block
      )
    else
      nil
    end
  end

  # 🔥 ENHANCED: Create job entry with better data structure
  defp create_enhanced_job_entry(company, title, date_range, full_text) do
    {start_date, end_date, current} = parse_date_range_enhanced(date_range)

    # Extract description and responsibilities from the full text
    description = extract_job_description_enhanced(company, title, full_text)
    responsibilities = extract_responsibilities_enhanced(full_text)
    achievements = extract_achievements_enhanced(full_text)
    technologies = extract_technologies_from_job(full_text)

    %{
      "company" => clean_company_name(company),
      "title" => clean_job_title(title),
      "location" => extract_job_location(full_text),
      "employment_type" => detect_employment_type(full_text),
      "start_date" => start_date,
      "end_date" => end_date,
      "current" => current,
      "description" => description,
      "responsibilities" => responsibilities,
      "achievements" => achievements,
      "skills" => technologies,
      "company_logo" => "",
      "company_url" => ""
    }
  end

  # 🔥 ENHANCED: Parse date ranges with better accuracy
  defp parse_date_range_enhanced(date_range) do
    cleaned = String.downcase(String.trim(date_range))

    cond do
      String.contains?(cleaned, "current") || String.contains?(cleaned, "present") ->
        start_date = String.replace(cleaned, ~r/\s*[-–—]\s*(current|present).*$/i, "") |> String.trim()
        {normalize_date(start_date), "", true}

      String.contains?(cleaned, "–") || String.contains?(cleaned, "-") || String.contains?(cleaned, "to") ->
        parts = String.split(cleaned, ~r/\s*[-–—]\s*|to\s+/i, parts: 2)
        case parts do
          [start_part, end_part] ->
            {normalize_date(start_part), normalize_date(end_part), false}
          [single_part] ->
            {normalize_date(single_part), "", false}
        end

      String.match?(cleaned, ~r/\d{4}/) ->
        {normalize_date(cleaned), "", false}

      true ->
        {"", "", false}
    end
  end

  # 🔥 NEW: Helper functions for job parsing
  defp normalize_date(date_str) do
    date_str
    |> String.trim()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp clean_company_name(company) do
    company
    |> String.trim()
    |> String.replace(~r/[^\w\s&.-]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp clean_job_title(title) do
    title
    |> String.trim()
    |> String.replace(~r/[^\w\s&.-]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp extract_job_location(text) do
    location_patterns = [
      ~r/([A-Z][a-z]+,\s*[A-Z]{2})/,
      ~r/([A-Z][a-z]+\s+[A-Z][a-z]+,\s*[A-Z]{2})/,
      ~r/Remote/i,
      ~r/([A-Z][a-z]+,\s*[A-Z][a-z]+)/
    ]

    Enum.find_value(location_patterns, "", fn pattern ->
      case Regex.run(pattern, text) do
        [_, location] -> String.trim(location)
        [location] -> String.trim(location)
        _ -> nil
      end
    end)
  end

  defp detect_employment_type(text) do
    text_lower = String.downcase(text)

    cond do
      String.contains?(text_lower, ["full-time", "full time"]) -> "Full-time"
      String.contains?(text_lower, ["part-time", "part time"]) -> "Part-time"
      String.contains?(text_lower, ["contract", "contractor"]) -> "Contract"
      String.contains?(text_lower, ["freelance", "freelancer"]) -> "Freelance"
      String.contains?(text_lower, ["intern", "internship"]) -> "Internship"
      String.contains?(text_lower, ["consultant", "consulting"]) -> "Consulting"
      true -> "Full-time"
    end
  end

  defp extract_job_description_enhanced(company, title, full_text) do
    # Look for text around the company/title mention
    company_lower = String.downcase(company)
    title_lower = String.downcase(title)
    text_lower = String.downcase(full_text)

    # Find the position of company or title in text
    company_pos = :binary.match(text_lower, company_lower)
    title_pos = :binary.match(text_lower, title_lower)

    start_pos = case {company_pos, title_pos} do
      {{pos, _}, :nomatch} -> pos
      {:nomatch, {pos, _}} -> pos
      {{pos1, _}, {pos2, _}} -> min(pos1, pos2)
      _ -> 0
    end

    # Extract surrounding context (up to 500 characters)
    context_start = max(0, start_pos - 100)
    context_length = min(500, String.length(full_text) - context_start)

    String.slice(full_text, context_start, context_length)
    |> String.trim()
  end

  defp extract_responsibilities_enhanced(text) do
    # Look for bullet points and numbered lists
    bullet_patterns = [
      ~r/^[•·▪▫‣⁃]\s*(.+)$/m,
      ~r/^[-*]\s*(.+)$/m,
      ~r/^\d+\.\s*(.+)$/m,
      ~r/^[a-z]\)\s*(.+)$/m
    ]

    all_responsibilities = bullet_patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, text)
      |> Enum.map(fn [_, resp] -> String.trim(resp) end)
    end)
    |> Enum.uniq()
    |> Enum.filter(fn resp ->
      String.length(resp) > 10 && String.length(resp) < 200
    end)
    |> Enum.take(8)  # Limit to 8 responsibilities

    if length(all_responsibilities) == 0 do
      # Fallback: extract sentences that look like responsibilities
      text
      |> String.split(~r/[.!?]+/)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn sentence ->
        sentence_lower = String.downcase(sentence)
        String.contains?(sentence_lower, ["responsible", "managed", "developed", "led", "implemented", "designed", "created", "coordinated"]) &&
        String.length(sentence) > 20 && String.length(sentence) < 200
      end)
      |> Enum.take(5)
    else
      all_responsibilities
    end
  end

  defp extract_achievements_enhanced(text) do
    achievement_keywords = ["achieved", "increased", "decreased", "improved", "reduced", "saved", "generated", "delivered", "exceeded", "won", "awarded"]

    text
    |> String.split(~r/[.!?]+/)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn sentence ->
      sentence_lower = String.downcase(sentence)
      Enum.any?(achievement_keywords, &String.contains?(sentence_lower, &1)) &&
      (Regex.match?(~r/\d+%/, sentence) || Regex.match?(~r/\$\d+/, sentence) || String.length(sentence) > 30) &&
      String.length(sentence) < 200
    end)
    |> Enum.take(5)
  end

  defp extract_technologies_from_job(text) do
    # Common technology patterns
    tech_patterns = [
      # Programming languages
      ~r/\b(JavaScript|Python|Java|C\+\+|C#|Ruby|Go|Rust|Swift|Kotlin|PHP|TypeScript|Scala|R|MATLAB|SQL|HTML|CSS)\b/i,
      # Frameworks and libraries
      ~r/\b(React|Vue|Angular|Node\.js|Express|Django|Flask|Spring|Laravel|Rails|Next\.js|Gatsby|Nuxt|Svelte)\b/i,
      # Tools and platforms
      ~r/\b(Git|Docker|Kubernetes|AWS|Azure|GCP|Jenkins|GitLab|GitHub|npm|webpack|babel|eslint|jest|cypress)\b/i,
      # Databases
      ~r/\b(MySQL|PostgreSQL|MongoDB|Redis|Elasticsearch|SQLite|Oracle|SQL Server|DynamoDB|Firebase)\b/i
    ]

    tech_patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, text)
      |> Enum.map(fn [match | _] -> match end)
    end)
    |> Enum.uniq()
    |> Enum.take(10)
  end

  defp create_enhanced_fallback_job(text) do
    # Try to extract any meaningful information
    lines = String.split(text, "\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    # Look for potential company names (lines with business indicators)
    potential_company = Enum.find(lines, fn line ->
      String.contains?(String.downcase(line), ["inc", "corp", "llc", "company", "ltd", "organization", "agency"]) &&
      String.length(line) < 100 && String.length(line) > 3
    end)

    # Look for potential job titles (lines with job-related words)
    potential_title = Enum.find(lines, fn line ->
      job_words = ["engineer", "manager", "developer", "analyst", "consultant", "specialist", "coordinator", "director", "lead", "senior", "associate", "intern"]
      String.contains?(String.downcase(line), job_words) &&
      String.length(line) < 100 && String.length(line) > 5
    end)

    # Look for dates
    potential_dates = Enum.find(lines, fn line ->
      Regex.match?(~r/\b\d{4}\b/, line) && String.length(line) < 50
    end)

    %{
      "company" => potential_company || "Professional Experience",
      "title" => potential_title || "Professional Role",
      "location" => "",
      "employment_type" => "Full-time",
      "start_date" => "",
      "end_date" => "",
      "current" => false,
      "description" => String.slice(text, 0, 400),
      "responsibilities" => extract_responsibilities_enhanced(text),
      "achievements" => [],
      "skills" => extract_technologies_from_job(text),
      "company_logo" => "",
      "company_url" => ""
    }
  end

  # Keep all the simple extraction functions for achievements and languages
  defp extract_achievements_simple(text) do
    # Look for achievements section
    if String.contains?(String.downcase(text), ["achievement", "award", "honor"]) do
      String.slice(text, 0, 300)
    else
      ""
    end
  end

  defp extract_languages_simple(text) do
    # Look for languages section
    if String.contains?(String.downcase(text), ["language", "fluent", "native", "bilingual"]) do
      String.slice(text, 0, 200)
    else
      ""
    end
  end

# PART 3 OF 3: Education, Skills & Personal Info Extraction

  # 🔥 ENHANCED: Education extraction
  defp extract_education_enhanced(text) do
    IO.puts("🔍 EDUCATION ENHANCED: Starting enhanced education extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for "EDUCATION" section header
    education_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["education", "academic background", "qualifications", "degrees"] ||
      (String.contains?(line_clean, "education") && String.length(line_clean) < 30)
    end)

    if education_start do
      IO.puts("🔍 EDUCATION ENHANCED: Found education section at line #{education_start}")

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

      IO.puts("🔍 EDUCATION ENHANCED: Extracted #{length(education_lines)} lines of education")

      if String.length(education_text) > 20 do
        parse_education_enhanced(education_text)
      else
        []
      end
    else
      IO.puts("🔍 EDUCATION ENHANCED: No education section found")
      []
    end
  end

  # 🔥 ENHANCED: Parse education with better structure
  defp parse_education_enhanced(education_text) do
    # Try to parse structured education entries
    education_entries = parse_structured_education(education_text)

    if length(education_entries) > 0 do
      education_entries
    else
      # Fallback to simple education entry
      [%{
        "degree" => extract_degree_from_text(education_text),
        "field" => extract_field_from_text(education_text),
        "institution" => extract_institution_from_text(education_text),
        "location" => "",
        "start_date" => "",
        "end_date" => extract_graduation_year(education_text),
        "status" => "Completed",
        "gpa" => extract_gpa(education_text),
        "description" => String.slice(education_text, 0, 200),
        "relevant_coursework" => [],
        "activities" => [],
        "institution_logo" => "",
        "institution_url" => ""
      }]
    end
  end

  # 🔥 NEW: Parse structured education entries
  defp parse_structured_education(text) do
    # Look for patterns like "Bachelor of Science in Computer Science, University Name, 2020"
    degree_patterns = [
      ~r/(Bachelor|Master|PhD|Doctorate|Associate|B\.S\.|M\.S\.|B\.A\.|M\.A\.)[\s\w]*(?:in\s+)?([\w\s]+),\s*([^,\n]+),\s*(\d{4})/i,
      ~r/([\w\s]+)\s+at\s+([^,\n]+),?\s*(\d{4})?/i
    ]

    degree_patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, text)
      |> Enum.map(&parse_education_match/1)
    end)
    |> Enum.reject(&is_nil/1)
  end

  # 🔥 NEW: Parse education match
  defp parse_education_match([_, degree, field, institution, year]) do
    %{
      "degree" => String.trim(degree),
      "field" => String.trim(field),
      "institution" => String.trim(institution),
      "location" => "",
      "start_date" => "",
      "end_date" => String.trim(year),
      "status" => "Completed",
      "gpa" => "",
      "description" => "",
      "relevant_coursework" => [],
      "activities" => [],
      "institution_logo" => "",
      "institution_url" => ""
    }
  end
  defp parse_education_match([_, degree, institution, year]) do
    %{
      "degree" => String.trim(degree),
      "field" => "",
      "institution" => String.trim(institution),
      "location" => "",
      "start_date" => "",
      "end_date" => if(year, do: String.trim(year), else: ""),
      "status" => "Completed",
      "gpa" => "",
      "description" => "",
      "relevant_coursework" => [],
      "activities" => [],
      "institution_logo" => "",
      "institution_url" => ""
    }
  end
  defp parse_education_match(_), do: nil

  # 🔥 NEW: Extract degree from text
  defp extract_degree_from_text(text) do
    degree_patterns = [
      ~r/\b(Bachelor|Master|PhD|Doctorate|Associate|B\.S\.|M\.S\.|B\.A\.|M\.A\.)[\s\w]*/i,
      ~r/\b(Bachelor's|Master's|Doctorate)\s+\w+/i
    ]

    Enum.find_value(degree_patterns, "Degree", fn pattern ->
      case Regex.run(pattern, text) do
        [match | _] -> String.trim(match)
        _ -> nil
      end
    end)
  end

  # 🔥 NEW: Extract field from text
  defp extract_field_from_text(text) do
    field_patterns = [
      ~r/\bin\s+([\w\s]+)/i,
      ~r/\bof\s+([\w\s]+)/i
    ]

    Enum.find_value(field_patterns, "", fn pattern ->
      case Regex.run(pattern, text) do
        [_, field] -> String.trim(field) |> String.slice(0, 50)
        _ -> nil
      end
    end)
  end

  # 🔥 NEW: Extract institution from text
  defp extract_institution_from_text(text) do
    institution_patterns = [
      ~r/\b(University|College|Institute|School)\s+of\s+[\w\s]+/i,
      ~r/[\w\s]+\s+(University|College|Institute|School)/i
    ]

    Enum.find_value(institution_patterns, "Institution", fn pattern ->
      case Regex.run(pattern, text) do
        [match | _] -> String.trim(match)
        _ -> nil
      end
    end)
  end

  # 🔥 NEW: Extract graduation year
  defp extract_graduation_year(text) do
    case Regex.run(~r/\b(19|20)\d{2}\b/, text) do
      [year] -> year
      _ -> ""
    end
  end

  # 🔥 NEW: Extract GPA
  defp extract_gpa(text) do
    case Regex.run(~r/GPA:?\s*(\d+\.?\d*)/i, text) do
      [_, gpa] -> gpa
      _ -> ""
    end
  end

  # 🔥 ENHANCED: Skills extraction with better categorization
  defp extract_skills_enhanced(text) do
    IO.puts("🔍 SKILLS ENHANCED: Starting enhanced skills extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for "SKILLS" section header
    skills_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["skills", "technical skills", "core competencies", "expertise", "technologies"] ||
      (String.contains?(line_clean, "skills") && String.length(line_clean) < 30)
    end)

    if skills_start do
      IO.puts("🔍 SKILLS ENHANCED: Found skills section at line #{skills_start}")

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

      IO.puts("🔍 SKILLS ENHANCED: Extracted #{length(skills_lines)} lines of skills")
      IO.puts("🔍 SKILLS ENHANCED: Content: #{skills_text}")

      if String.length(skills_text) > 10 do
        parse_skills_enhanced(skills_text)
      else
        []
      end
    else
      IO.puts("🔍 SKILLS ENHANCED: No skills section found, extracting from full text")
      extract_skills_from_full_text(text)
    end
  end

  # 🔥 ENHANCED: Parse skills with multiple separators
  defp parse_skills_enhanced(skills_text) do
    # Handle multiple separator types
    separators = [",", "|", "•", "·", "▪", "▫", "‣", "⁃", ";", "\n"]

    # Try each separator and pick the one that gives the most reasonable results
    results = separators
    |> Enum.map(fn sep ->
      skills = skills_text
      |> String.split(sep)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn skill ->
        String.length(skill) > 2 && String.length(skill) < 50 &&
        !Regex.match?(~r/^\d+$/, skill) &&
        !String.contains?(String.downcase(skill), ["skills", "technologies", "expertise"])
      end)
      |> Enum.map(&clean_skill_name/1)
      |> Enum.uniq()

      {sep, skills}
    end)
    |> Enum.max_by(fn {_sep, skills} -> length(skills) end)

    case results do
      {_sep, skills} when length(skills) > 0 ->
        IO.puts("🔍 SKILLS ENHANCED: Found #{length(skills)} skills")
        skills |> Enum.take(50)  # Limit to 50 skills
      _ ->
        # Fallback: split by any whitespace and filter
        skills_text
        |> String.split(~r/\s+/)
        |> Enum.filter(fn word ->
          String.length(word) > 3 && is_tech_skill?(word)
        end)
        |> Enum.take(20)
    end
  end

  # 🔥 NEW: Extract skills from full text when no skills section found
  defp extract_skills_from_full_text(text) do
    IO.puts("🔍 SKILLS ENHANCED: Extracting skills from full text")

    # Common technology and skill keywords
    tech_keywords = [
      # Programming Languages
      "JavaScript", "Python", "Java", "C++", "C#", "Ruby", "Go", "Rust", "Swift", "Kotlin", "PHP", "TypeScript",
      # Frameworks
      "React", "Vue", "Angular", "Node.js", "Express", "Django", "Flask", "Spring", "Laravel", "Rails",
      # Tools
      "Git", "Docker", "Kubernetes", "AWS", "Azure", "Jenkins", "GitHub", "GitLab",
      # Databases
      "MySQL", "PostgreSQL", "MongoDB", "Redis", "SQL",
      # Soft Skills
      "Leadership", "Communication", "Project Management", "Team Management", "Problem Solving"
    ]

    found_skills = tech_keywords
    |> Enum.filter(fn keyword ->
      String.contains?(text, keyword)
    end)
    |> Enum.take(20)

    IO.puts("🔍 SKILLS ENHANCED: Found #{length(found_skills)} skills from full text")
    found_skills
  end

  # 🔥 NEW: Clean skill name
  defp clean_skill_name(skill) do
    skill
    |> String.trim()
    |> String.replace(~r/[^\w\s.#+()-]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # 🔥 NEW: Check if word is a tech skill
  defp is_tech_skill?(word) do
    tech_patterns = [
      ~r/^[A-Z][a-z]+$/,  # Capitalized words
      ~r/\.(js|py|rb|php|sql)$/i,  # File extensions
      ~r/^(HTML|CSS|SQL|API|SDK|IDE)$/i  # Common acronyms
    ]

    Enum.any?(tech_patterns, &Regex.match?(&1, word))
  end

  # 🔥 ENHANCED: Projects extraction
  defp extract_projects_enhanced(text) do
    IO.puts("🔍 PROJECTS ENHANCED: Starting enhanced projects extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for projects section
    projects_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["projects", "portfolio", "work samples", "personal projects"] ||
      (String.contains?(line_clean, "project") && String.length(line_clean) < 30)
    end)

    if projects_start do
      IO.puts("🔍 PROJECTS ENHANCED: Found projects section")

      next_section = Enum.drop(lines, projects_start + 1)
      |> Enum.find_index(fn line ->
        line_clean = String.trim(line) |> String.downcase()
        line_clean in ["experience", "education", "skills", "certifications"] ||
        (String.length(line_clean) < 30 && String.match?(line_clean, ~r/^[a-z\s]+$/))
      end)

      end_index = if next_section, do: projects_start + next_section + 1, else: length(lines)
      projects_lines = Enum.slice(lines, (projects_start + 1)..(end_index - 1))
      projects_text = Enum.join(projects_lines, "\n")

      if String.length(projects_text) > 30 do
        parse_projects_enhanced(projects_text)
      else
        []
      end
    else
      []
    end
  end

  # 🔥 ENHANCED: Parse projects with better structure
  defp parse_projects_enhanced(projects_text) do
    # Try to identify individual projects
    project_blocks = String.split(projects_text, ~r/\n\s*\n/, trim: true)
    |> Enum.filter(fn block -> String.length(block) > 20 end)
    |> Enum.map(&parse_project_block/1)
    |> Enum.reject(&is_nil/1)

    if length(project_blocks) > 0 do
      project_blocks
    else
      # Fallback: create single project
      [%{
        "title" => extract_project_title(projects_text),
        "description" => String.slice(projects_text, 0, 300),
        "technologies" => extract_technologies_from_job(projects_text),
        "role" => "Developer",
        "start_date" => "",
        "end_date" => "",
        "status" => "Completed",
        "demo_url" => extract_url_from_text(projects_text, "demo"),
        "github_url" => extract_url_from_text(projects_text, "github"),
        "featured_image" => "",
        "screenshots" => [],
        "team_size" => 1,
        "my_contribution" => "Full development"
      }]
    end
  end

  # 🔥 NEW: Parse individual project block
  defp parse_project_block(block) do
    lines = String.split(block, "\n", trim: true)

    # First line is likely the title
    title = Enum.at(lines, 0, "Project")
    |> clean_project_title()

    %{
      "title" => title,
      "description" => String.slice(block, 0, 300),
      "technologies" => extract_technologies_from_job(block),
      "role" => "Developer",
      "start_date" => "",
      "end_date" => "",
      "status" => "Completed",
      "demo_url" => extract_url_from_text(block, "demo"),
      "github_url" => extract_url_from_text(block, "github"),
      "featured_image" => "",
      "screenshots" => [],
      "team_size" => 1,
      "my_contribution" => "Development and implementation"
    }
  end

  # 🔥 NEW: Extract project title
  defp extract_project_title(text) do
    lines = String.split(text, "\n", trim: true)

    # Look for a line that looks like a title
    title = Enum.find(lines, fn line ->
      cleaned = String.trim(line)
      String.length(cleaned) > 5 && String.length(cleaned) < 100 &&
      !String.contains?(String.downcase(cleaned), ["description", "technologies", "built", "using"])
    end)

    clean_project_title(title || "Project")
  end

  # 🔥 NEW: Clean project title
  defp clean_project_title(title) do
    title
    |> String.trim()
    |> String.replace(~r/^[•·▪▫‣⁃\-*\d+\.\s]+/, "")
    |> String.trim()
    |> case do
      "" -> "Project"
      cleaned -> cleaned
    end
  end

  # 🔥 NEW: Extract URL from text
  defp extract_url_from_text(text, type) do
    case type do
      "github" ->
        case Regex.run(~r/github\.com\/[\w\-_]+\/[\w\-_]+/i, text) do
          [url] -> "https://" <> url
          _ -> ""
        end
      "demo" ->
        case Regex.run(~r/https?:\/\/[^\s]+\.[^\s]+/i, text) do
          [url] -> String.trim(url, ".,")
          _ -> ""
        end
      _ -> ""
    end
  end

  # 🔥 ENHANCED: Certifications extraction
  defp extract_certifications_enhanced(text) do
    IO.puts("🔍 CERTIFICATIONS ENHANCED: Starting enhanced certifications extraction")

    lines = String.split(text, "\n", trim: true)

    # Look for certifications section
    cert_start = Enum.find_index(lines, fn line ->
      line_clean = String.trim(line) |> String.downcase()
      line_clean in ["certifications", "certificates", "licenses", "achievements", "awards"] ||
      (String.contains?(line_clean, "certif") && String.length(line_clean) < 30)
    end)

    if cert_start do
      IO.puts("🔍 CERTIFICATIONS ENHANCED: Found certifications section")

      next_section = Enum.drop(lines, cert_start + 1)
      |> Enum.find_index(fn line ->
        line_clean = String.trim(line) |> String.downcase()
        line_clean in ["experience", "education", "skills", "projects"] ||
        (String.length(line_clean) < 30 && String.match?(line_clean, ~r/^[a-z\s]+$/))
      end)

      end_index = if next_section, do: cert_start + next_section + 1, else: length(lines)
      cert_lines = Enum.slice(lines, (cert_start + 1)..(end_index - 1))
      cert_text = Enum.join(cert_lines, "\n")

      if String.length(cert_text) > 20 do
        parse_certifications_enhanced(cert_text)
      else
        []
      end
    else
      []
    end
  end

  # 🔥 ENHANCED: Parse certifications with better structure
  defp parse_certifications_enhanced(cert_text) do
    # Look for certification patterns
    cert_lines = String.split(cert_text, "\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_certification_line/1)
    |> Enum.reject(&is_nil/1)

    if length(cert_lines) > 0 do
      cert_lines
    else
      # Fallback: create basic certifications from text
      cert_text
      |> String.split(~r/[,;•·▪▫‣⁃\n]/)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(String.length(&1) > 10))
      |> Enum.map(fn cert ->
        %{
          "name" => cert,
          "issuer" => "",
          "date_earned" => "",
          "expiry_date" => "",
          "credential_id" => "",
          "verification_url" => ""
        }
      end)
      |> Enum.take(10)
    end
  end

  # 🔥 NEW: Parse individual certification line
  defp parse_certification_line(line) do
    # Remove bullet points and clean
    cleaned = String.replace(line, ~r/^[•·▪▫‣⁃\-*\d+\.\s]+/, "") |> String.trim()

    if String.length(cleaned) > 5 do
      # Try to extract issuer and date
      issuer = extract_issuer_from_cert(cleaned)
      date = extract_date_from_cert(cleaned)
      cert_name = clean_cert_name(cleaned)

      %{
        "name" => cert_name,
        "issuer" => issuer,
        "date_earned" => date,
        "expiry_date" => "",
        "credential_id" => "",
        "verification_url" => ""
      }
    else
      nil
    end
  end

  # 🔥 NEW: Extract issuer from certification
  defp extract_issuer_from_cert(text) do
    issuer_patterns = [
      ~r/\bby\s+([^,\n]+)/i,
      ~r/\bfrom\s+([^,\n]+)/i,
      ~r/\b(AWS|Google|Microsoft|Oracle|Cisco|Adobe|Salesforce|CompTIA)\b/i
    ]

    Enum.find_value(issuer_patterns, "", fn pattern ->
      case Regex.run(pattern, text) do
        [_, issuer] -> String.trim(issuer)
        [issuer] -> String.trim(issuer)
        _ -> nil
      end
    end)
  end

  # 🔥 NEW: Extract date from certification
  defp extract_date_from_cert(text) do
    case Regex.run(~r/\b(19|20)\d{2}\b/, text) do
      [year] -> year
      _ -> ""
    end
  end

  # 🔥 NEW: Clean certification name
  defp clean_cert_name(text) do
    text
    |> String.replace(~r/\s*[-–—]\s*(19|20)\d{2}.*$/, "")
    |> String.replace(~r/\s*\bby\s+.*$/i, "")
    |> String.replace(~r/\s*\bfrom\s+.*$/i, "")
    |> String.trim()
  end

  # 🔥 ENHANCED: Process skills with AI detection (the key function for creating proper data structure)
  defp process_skills_with_ai_detection(basic_skills, full_text, work_experience) do
    IO.puts("🔍 SKILLS AI: Processing #{length(basic_skills)} skills with AI detection")

    # Create enhanced skills with proficiency and years
    enhanced_skills = basic_skills
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

    # Group skills by category for the categorized view
    skill_categories = enhanced_skills
    |> Enum.group_by(fn skill -> skill["category"] end)
    |> Enum.into(%{})

    # Return both flat skills and categorized skills
    %{
      "flat_skills" => enhanced_skills |> Enum.map(fn skill -> skill["name"] end),
      "skill_categories" => skill_categories,
      "enhanced_skills" => enhanced_skills,
      "skill_display_mode" => "categorized",
      "show_proficiency" => true,
      "show_years" => true,
      "imported_from_resume" => true
    }
  end

  # Keep all the existing personal info and summary extraction functions
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

  # Keep the enhanced skills processing functions
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
          Map.get(job, "skills", []) |> Enum.join(" ")
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
