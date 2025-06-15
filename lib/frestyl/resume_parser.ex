# lib/frestyl/resume_parser.ex - Enhanced Resume Parser
defmodule Frestyl.ResumeParser do
  @moduledoc """
  Enhanced resume parsing with AI integration and multiple file format support.
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

  defp extract_from_pdf(file_path) do
    # Try multiple PDF extraction methods
    case System.cmd("pdftotext", [file_path, "-"], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 0 ->
        {:ok, clean_extracted_text(text)}

      {_, _} ->
        # Fallback to Python-based extraction
        extract_pdf_with_python(file_path)
    end
  rescue
    _ ->
      extract_pdf_with_python(file_path)
  end

  defp extract_pdf_with_python(file_path) do
    python_script = """
    import PyPDF2
    import sys
    try:
        with open('#{file_path}', 'rb') as file:
            reader = PyPDF2.PdfReader(file)
            text = ''
            for page in reader.pages:
                text += page.extract_text() + '\\n'
        print(text)
    except Exception as e:
        sys.stderr.write(str(e))
        sys.exit(1)
    """

    case System.cmd("python3", ["-c", python_script], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 0 ->
        {:ok, clean_extracted_text(text)}

      {error, _} ->
        Logger.warning("PDF extraction failed: #{error}")
        {:error, "Could not extract text from PDF"}
    end
  rescue
    _ ->
      {:error, "PDF extraction not available"}
  end

  defp extract_from_docx(file_path) do
    # Try using python-docx
    python_script = """
    from docx import Document
    import sys
    try:
        doc = Document('#{file_path}')
        text = ''
        for paragraph in doc.paragraphs:
            text += paragraph.text + '\\n'
        print(text)
    except Exception as e:
        sys.stderr.write(str(e))
        sys.exit(1)
    """

    case System.cmd("python3", ["-c", python_script], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 0 ->
        {:ok, clean_extracted_text(text)}

      {_, _} ->
        # Fallback to unzip and XML parsing
        extract_docx_manual(file_path)
    end
  rescue
    _ ->
      extract_docx_manual(file_path)
  end

  defp extract_docx_manual(file_path) do
    # DOCX is a ZIP file with XML content
    case System.cmd("unzip", ["-p", file_path, "word/document.xml"], stderr_to_stdout: true) do
      {xml_content, 0} ->
        text = xml_content
               |> String.replace(~r/<[^>]+>/, " ")  # Remove XML tags
               |> String.replace(~r/\s+/, " ")      # Normalize whitespace
               |> String.trim()

        {:ok, text}

      {_, _} ->
        {:error, "Could not extract DOCX content"}
    end
  rescue
    _ ->
      {:error, "DOCX extraction failed"}
  end

  defp extract_from_doc(file_path) do
    # Try antiword for .doc files
    case System.cmd("antiword", [file_path], stderr_to_stdout: true) do
      {text, 0} when byte_size(text) > 0 ->
        {:ok, clean_extracted_text(text)}

      {_, _} ->
        {:error, "Could not extract DOC content. Please convert to DOCX or PDF."}
    end
  rescue
    _ ->
      {:error, "DOC extraction not available. Please convert to DOCX or PDF."}
  end

  defp extract_from_rtf(file_path) do
    # Basic RTF parsing - strip RTF control codes
    case File.read(file_path) do
      {:ok, content} ->
        text = content
               |> String.replace(~r/\\[a-z]+\d*\s?/, " ")  # Remove RTF control words
               |> String.replace(~r/[{}]/, " ")            # Remove braces
               |> String.replace(~r/\s+/, " ")             # Normalize whitespace
               |> String.trim()

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

  # Parse extracted text into structured data
  defp parse_resume_text(text, filename) do
    try do
      # Enhanced parsing with multiple strategies
      parsed_data = %{
        "filename" => filename,
        "raw_text" => text,
        "personal_info" => extract_personal_info(text),
        "professional_summary" => extract_professional_summary(text),
        "work_experience" => extract_work_experience(text),
        "education" => extract_education(text),
        "skills" => extract_skills(text),
        "projects" => extract_projects(text),
        "certifications" => extract_certifications(text),
        "achievements" => extract_achievements(text),
        "languages" => extract_languages(text)
      }

      {:ok, parsed_data}
    rescue
      error ->
        Logger.error("Resume parsing failed: #{Exception.message(error)}")
        {:error, "Failed to parse resume content"}
    end
  end

  # Extract personal information
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
    # Look for name patterns at the beginning of the resume
    lines = String.split(text, "\n", trim: true)

    # Get first few non-empty lines and look for name patterns
    candidates =
      lines
      |> Enum.take(5)
      |> Enum.filter(&(String.length(&1) > 2 && String.length(&1) < 50))
      |> Enum.filter(&name_candidate?/1)

    case candidates do
      [first_candidate | _] -> String.trim(first_candidate)
      [] -> ""
    end
  end

  defp name_candidate?(line) do
    # Simple heuristics for name detection
    words = String.split(line, " ", trim: true)
    length(words) >= 2 &&
    length(words) <= 4 &&
    Enum.all?(words, &String.match?(&1, ~r/^[A-Z][a-z]+$/)) &&
    !String.contains?(String.downcase(line), ["email", "phone", "address", "resume", "cv"])
  end

  defp extract_email(text) do
    case Regex.run(~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, text) do
      [email] -> email
      _ -> ""
    end
  end

  defp extract_phone(text) do
    # Multiple phone number patterns
    patterns = [
      ~r/\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/,  # (123) 456-7890, 123-456-7890
      ~r/\+1[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/,  # +1 (123) 456-7890
      ~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/  # 123 456 7890
    ]

    Enum.find_value(patterns, "", fn pattern ->
      case Regex.run(pattern, text) do
        [phone] -> String.trim(phone)
        _ -> nil
      end
    end)
  end

  defp extract_location(text) do
    # Look for city, state patterns
    location_patterns = [
      ~r/([A-Z][a-z]+,\s*[A-Z]{2})/,  # City, ST
      ~r/([A-Z][a-z]+\s+[A-Z][a-z]+,\s*[A-Z]{2})/,  # City Name, ST
      ~r/([A-Z][a-z]+,\s*[A-Z][a-z]+)/  # City, Country
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

  # Extract professional summary
  defp extract_professional_summary(text) do
    lines = String.split(text, "\n", trim: true)

    # Look for summary/objective sections
    summary_indicators = ["summary", "objective", "profile", "about", "overview"]

    Enum.find_value(lines, "", fn line ->
      if Enum.any?(summary_indicators, &String.contains?(String.downcase(line), &1)) do
        # Find the next few lines after summary heading
        index = Enum.find_index(lines, &(&1 == line))
        if index do
          lines
          |> Enum.drop(index + 1)
          |> Enum.take_while(&(!section_header?(&1)))
          |> Enum.take(5)  # Limit to 5 lines
          |> Enum.join(" ")
          |> String.trim()
        end
      end
    end)
  end

  # Extract work experience
  defp extract_work_experience(text) do
    lines = String.split(text, "\n", trim: true)

    # Find experience section
    exp_start = find_section_start(lines, ["experience", "employment", "work history", "career"])

    if exp_start do
      exp_lines =
        lines
        |> Enum.drop(exp_start + 1)
        |> Enum.take_while(&(!next_major_section?(&1)))

      parse_experience_entries(exp_lines)
    else
      []
    end
  end

  defp parse_experience_entries(lines) do
    # Group lines into job entries based on patterns
    job_entries = []
    current_job = %{}

    Enum.reduce(lines, [], fn line, acc ->
      cond do
        job_title_line?(line) ->
          if map_size(current_job) > 0 do
            [current_job | acc]
          else
            acc
          end

        company_line?(line) ->
          acc

        date_line?(line) ->
          acc

        true ->
          acc
      end
    end)
    |> Enum.reverse()
    |> Enum.take(10)  # Limit to 10 most recent jobs
  end

  defp job_title_line?(line) do
    # Heuristics for job title detection
    words = String.split(line, " ")
    length(words) <= 6 &&
    String.match?(line, ~r/^[A-Z]/) &&
    !String.contains?(String.downcase(line), ["•", "-", "responsibilities"])
  end

  defp company_line?(line) do
    # Look for company indicators
    String.contains?(String.downcase(line), ["inc", "llc", "corp", "company", "ltd"])
  end

  defp date_line?(line) do
    # Look for date patterns
    String.match?(line, ~r/\d{4}/) ||
    String.contains?(String.downcase(line), ["january", "february", "march", "april", "may", "june",
                                            "july", "august", "september", "october", "november", "december"]) ||
    String.contains?(line, ["present", "current"])
  end

  # Extract education
  defp extract_education(text) do
    lines = String.split(text, "\n", trim: true)

    edu_start = find_section_start(lines, ["education", "academic", "qualifications"])

    if edu_start do
      edu_lines =
        lines
        |> Enum.drop(edu_start + 1)
        |> Enum.take_while(&(!next_major_section?(&1)))

      parse_education_entries(edu_lines)
    else
      []
    end
  end

  defp parse_education_entries(lines) do
    # Simple education parsing
    lines
    |> Enum.filter(&education_entry?/1)
    |> Enum.map(&parse_single_education/1)
    |> Enum.reject(&is_nil/1)
  end

  defp education_entry?(line) do
    String.contains?(String.downcase(line), ["bachelor", "master", "phd", "degree", "university", "college", "institute"])
  end

  defp parse_single_education(line) do
    # Extract basic education info
    %{
      "institution" => extract_institution(line),
      "degree" => extract_degree(line),
      "field" => "",
      "year" => extract_year(line),
      "gpa" => extract_gpa(line)
    }
  end

  defp extract_institution(line) do
    # Look for institution names
    words = String.split(line, " ")
    institution_words = Enum.filter(words, &String.match?(&1, ~r/^[A-Z]/))
    Enum.join(institution_words, " ")
  end

  defp extract_degree(line) do
    degree_patterns = [
      ~r/Bachelor[^\s]*|B\.?[AS]\.?/i,
      ~r/Master[^\s]*|M\.?[AS]\.?/i,
      ~r/PhD|Ph\.?D\.?|Doctorate/i
    ]

    Enum.find_value(degree_patterns, "", fn pattern ->
      case Regex.run(pattern, line) do
        [degree] -> degree
        _ -> nil
      end
    end)
  end

  defp extract_year(line) do
    case Regex.run(~r/\b(19|20)\d{2}\b/, line) do
      [year] -> year
      _ -> ""
    end
  end

  defp extract_gpa(line) do
    case Regex.run(~r/GPA:?\s*(\d+\.?\d*)/i, line) do
      [_, gpa] -> gpa
      _ -> ""
    end
  end

  # Extract skills
  defp extract_skills(text) do
    lines = String.split(text, "\n", trim: true)

    skills_start = find_section_start(lines, ["skills", "technical skills", "core competencies", "expertise"])

    if skills_start do
      skills_lines =
        lines
        |> Enum.drop(skills_start + 1)
        |> Enum.take_while(&(!next_major_section?(&1)))
        |> Enum.join(" ")

      parse_skills_text(skills_lines)
    else
      # Try to extract skills from the entire text
      extract_common_skills(text)
    end
  end

  defp parse_skills_text(text) do
    # Split by common delimiters and clean up
    text
    |> String.split(~r/[,•·\-\n|;]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" || String.length(&1) < 2))
    |> Enum.map(&clean_skill_name/1)
    |> Enum.uniq()
    |> Enum.take(50)  # Limit to 50 skills
  end

  defp clean_skill_name(skill) do
    skill
    |> String.replace(~r/^\W+|\W+$/, "")  # Remove leading/trailing non-word chars
    |> String.trim()
  end

  defp extract_common_skills(text) do
    # Common technical skills to look for
    common_skills = [
      # Programming Languages
      "Python", "JavaScript", "Java", "C++", "C#", "Ruby", "PHP", "Go", "Rust", "Swift",
      "Kotlin", "TypeScript", "Scala", "R", "MATLAB", "SQL",

      # Frameworks & Libraries
      "React", "Angular", "Vue.js", "Node.js", "Express", "Django", "Flask", "Spring",
      "Laravel", "Rails", "Bootstrap", "jQuery",

      # Databases
      "MySQL", "PostgreSQL", "MongoDB", "Redis", "Elasticsearch", "Oracle", "SQLite",

      # Cloud & DevOps
      "AWS", "Azure", "Google Cloud", "Docker", "Kubernetes", "Jenkins", "Git", "Linux",
      "Apache", "Nginx",

      # Other Technical
      "Machine Learning", "Data Science", "Artificial Intelligence", "Blockchain",
      "Cybersecurity", "API", "REST", "GraphQL", "Microservices"
    ]

    found_skills =
      common_skills
      |> Enum.filter(&String.contains?(text, &1))
      |> Enum.uniq()

    found_skills
  end

  # Extract projects
  defp extract_projects(text) do
    lines = String.split(text, "\n", trim: true)

    projects_start = find_section_start(lines, ["projects", "portfolio", "personal projects", "side projects"])

    if projects_start do
      project_lines =
        lines
        |> Enum.drop(projects_start + 1)
        |> Enum.take_while(&(!next_major_section?(&1)))

      parse_project_entries(project_lines)
    else
      []
    end
  end

  defp parse_project_entries(lines) do
    # Simple project parsing - each significant line is a project
    lines
    |> Enum.filter(&project_entry?/1)
    |> Enum.map(&parse_single_project/1)
    |> Enum.take(10)  # Limit to 10 projects
  end

  defp project_entry?(line) do
    String.length(line) > 10 &&
    !String.starts_with?(line, "•") &&
    !String.starts_with?(line, "-") &&
    String.match?(line, ~r/^[A-Z]/)
  end

  defp parse_single_project(line) do
    %{
      "title" => extract_project_title(line),
      "description" => line,
      "technologies" => extract_technologies_from_line(line),
      "url" => extract_url_from_line(line),
      "github_url" => extract_github_from_line(line)
    }
  end

  defp extract_project_title(line) do
    # First few words usually contain the title
    line
    |> String.split(" ")
    |> Enum.take(4)
    |> Enum.join(" ")
    |> String.replace(~r/[^\w\s]/, "")
    |> String.trim()
  end

  defp extract_technologies_from_line(line) do
    # Look for technology names in parentheses or after keywords
    tech_keywords = ["built with", "using", "technologies:", "stack:"]

    # Extract technologies mentioned in the line
    common_techs = ["React", "Python", "JavaScript", "Node.js", "MongoDB", "PostgreSQL", "AWS", "Docker"]

    common_techs
    |> Enum.filter(&String.contains?(line, &1))
  end

  defp extract_url_from_line(line) do
    case Regex.run(~r/https?:\/\/[^\s]+/, line) do
      [url] -> String.trim(url, ".,)")
      _ -> ""
    end
  end

  defp extract_github_from_line(line) do
    case Regex.run(~r/github\.com\/[\w-]+\/[\w-]+/, line) do
      [github] -> "https://" <> github
      _ -> ""
    end
  end

  # Extract certifications
  defp extract_certifications(text) do
    lines = String.split(text, "\n", trim: true)

    cert_start = find_section_start(lines, ["certifications", "certificates", "licenses", "credentials"])

    if cert_start do
      cert_lines =
        lines
        |> Enum.drop(cert_start + 1)
        |> Enum.take_while(&(!next_major_section?(&1)))

      parse_certification_entries(cert_lines)
    else
      []
    end
  end

  defp parse_certification_entries(lines) do
    lines
    |> Enum.filter(&certification_entry?/1)
    |> Enum.map(&parse_single_certification/1)
    |> Enum.take(20)  # Limit to 20 certifications
  end

  defp certification_entry?(line) do
    String.length(line) > 5 &&
    (String.contains?(String.downcase(line), ["certified", "certification", "aws", "microsoft", "google", "cisco"]) ||
     String.match?(line, ~r/^[A-Z]/))
  end

  defp parse_single_certification(line) do
    %{
      "title" => line,
      "provider" => extract_cert_provider(line),
      "date" => extract_year(line),
      "credential_id" => ""
    }
  end

  defp extract_cert_provider(line) do
    providers = ["AWS", "Microsoft", "Google", "Cisco", "Oracle", "Salesforce", "Adobe", "CompTIA"]

    Enum.find(providers, "", fn provider ->
      String.contains?(line, provider)
    end)
  end

  # Extract achievements
  defp extract_achievements(text) do
    lines = String.split(text, "\n", trim: true)

    achieve_start = find_section_start(lines, ["achievements", "accomplishments", "awards", "honors"])

    if achieve_start do
      achieve_lines =
        lines
        |> Enum.drop(achieve_start + 1)
        |> Enum.take_while(&(!next_major_section?(&1)))
        |> Enum.join("\n")

      achieve_lines
    else
      ""
    end
  end

  # Extract languages
  defp extract_languages(text) do
    lines = String.split(text, "\n", trim: true)

    lang_start = find_section_start(lines, ["languages", "language skills"])

    if lang_start do
      lang_lines =
        lines
        |> Enum.drop(lang_start + 1)
        |> Enum.take_while(&(!next_major_section?(&1)))
        |> Enum.join(" ")

      lang_lines
    else
      ""
    end
  end

  # Helper functions

  defp find_section_start(lines, keywords) do
    Enum.find_index(lines, fn line ->
      Enum.any?(keywords, &String.contains?(String.downcase(line), &1)) &&
      section_header?(line)
    end)
  end

  defp section_header?(line) do
    # Check if line looks like a section header
    trimmed = String.trim(line)
    String.length(trimmed) < 50 &&
    String.length(trimmed) > 3 &&
    (String.match?(trimmed, ~r/^[A-Z]/) ||
     String.contains?(trimmed, ":") ||
     String.match?(trimmed, ~r/^[A-Z\s]+$/))
  end

  defp next_major_section?(line) do
    major_sections = [
      "experience", "education", "skills", "projects", "certifications",
      "achievements", "languages", "references", "contact", "summary",
      "objective", "qualifications", "employment", "work history"
    ]

    section_header?(line) &&
    Enum.any?(major_sections, &String.contains?(String.downcase(line), &1))
  end
end
