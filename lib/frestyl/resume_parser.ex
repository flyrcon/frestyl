# Create a new file: lib/frestyl/resume_parser.ex

defmodule Frestyl.ResumeParser do
  @moduledoc """
  Parses resume files (PDF, DOC, DOCX) and extracts structured information.
  """

  require Logger

  @doc """
  Parses a resume file and extracts structured data.
  """
  def parse_resume(file_path) do
    Logger.info("Parsing resume file: #{file_path}")

    case extract_text_from_file(file_path) do
      {:ok, text} ->
        parsed_data = parse_resume_text(text)
        {:ok, parsed_data}

      {:error, reason} ->
        Logger.error("Failed to extract text from resume: #{reason}")
        {:error, "Unable to read resume file: #{reason}"}
    end
  end

  @doc """
  Extracts text from different file types.
  """
  defp extract_text_from_file(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".pdf" -> extract_text_from_pdf(file_path)
      ".doc" -> extract_text_from_doc(file_path)
      ".docx" -> extract_text_from_docx(file_path)
      ext -> {:error, "Unsupported file type: #{ext}"}
    end
  end

  # PDF text extraction using poppler-utils (pdftotext)
  defp extract_text_from_pdf(file_path) do
    case System.cmd("pdftotext", [file_path, "-"], stderr_to_stdout: true) do
      {text, 0} ->
        {:ok, text}
      {error, _} ->
        Logger.warning("pdftotext failed, trying python fallback: #{error}")
        extract_text_from_pdf_python(file_path)
    end
  rescue
    error ->
      Logger.error("PDF extraction error: #{inspect(error)}")
      {:error, "PDF extraction failed"}
  end

  # Fallback PDF extraction using Python (if available)
  defp extract_text_from_pdf_python(file_path) do
    python_script = """
    import sys
    try:
        import PyPDF2
        with open(sys.argv[1], 'rb') as file:
            reader = PyPDF2.PdfReader(file)
            text = ""
            for page in reader.pages:
                text += page.extract_text() + "\\n"
            print(text)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    """

    case System.cmd("python3", ["-c", python_script, file_path], stderr_to_stdout: true) do
      {text, 0} -> {:ok, text}
      {error, _} -> {:error, "Python PDF extraction failed: #{error}"}
    end
  rescue
    _ -> {:error, "PDF extraction not available"}
  end

  # DOC text extraction using antiword
  defp extract_text_from_doc(file_path) do
    case System.cmd("antiword", [file_path], stderr_to_stdout: true) do
      {text, 0} -> {:ok, text}
      {error, _} -> {:error, "DOC extraction failed: #{error}"}
    end
  rescue
    _ -> {:error, "DOC extraction not available (antiword not installed)"}
  end

  # DOCX text extraction using unzip and XML parsing
  defp extract_text_from_docx(file_path) do
    try do
      case System.cmd("unzip", ["-p", file_path, "word/document.xml"], stderr_to_stdout: true) do
        {xml_content, 0} ->
          text = extract_text_from_docx_xml(xml_content)
          {:ok, text}
        {error, _} ->
          {:error, "DOCX extraction failed: #{error}"}
      end
    rescue
      _ -> {:error, "DOCX extraction not available"}
    end
  end

  # Extract text from DOCX XML content
  defp extract_text_from_docx_xml(xml_content) do
    # Simple regex to extract text between <w:t> tags
    Regex.scan(~r/<w:t[^>]*>([^<]*)<\/w:t>/, xml_content)
    |> Enum.map(fn [_, text] -> text end)
    |> Enum.join(" ")
    |> String.trim()
  end

  @doc """
  Parses extracted text and identifies resume sections.
  """
  def parse_resume_text(text) do
    text = clean_text(text)
    sections = identify_sections(text)

    %{
      "professional_summary" => extract_section(sections, :summary),
      "work_experience" => extract_section(sections, :experience),
      "education" => extract_section(sections, :education),
      "skills" => extract_section(sections, :skills),
      "certifications" => extract_section(sections, :certifications)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Enum.into(%{})
  end

  # Clean and normalize text
  defp clean_text(text) do
    text
    |> String.replace(~r/\r\n|\r|\n/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Identify different resume sections using keywords and patterns
  defp identify_sections(text) do
    sections = %{
      summary: nil,
      experience: nil,
      education: nil,
      skills: nil,
      certifications: nil
    }

    # Split text into potential sections
    lines = String.split(text, ~r/\n+/)

    # Use keyword matching to identify sections
    Enum.reduce(lines, {sections, :unknown, []}, fn line, {acc_sections, current_section, buffer} ->
      section_type = identify_section_type(line)

      case section_type do
        :unknown ->
          {acc_sections, current_section, [line | buffer]}

        new_section when new_section != current_section ->
          # Save previous section and start new one
          updated_sections = if current_section != :unknown and length(buffer) > 0 do
            content = buffer |> Enum.reverse() |> Enum.join(" ") |> String.trim()
            Map.put(acc_sections, current_section, content)
          else
            acc_sections
          end

          {updated_sections, new_section, []}
      end
    end)
    |> elem(0)
  end

  # Identify section type based on keywords
  defp identify_section_type(line) do
    line_lower = String.downcase(line)

    cond do
      Regex.match?(~r/\b(summary|profile|objective|about)\b/, line_lower) -> :summary
      Regex.match?(~r/\b(experience|employment|work|career|professional)\b/, line_lower) -> :experience
      Regex.match?(~r/\b(education|academic|degree|university|college)\b/, line_lower) -> :education
      Regex.match?(~r/\b(skills|competencies|technologies|tools)\b/, line_lower) -> :skills
      Regex.match?(~r/\b(certifications|certificates|licenses)\b/, line_lower) -> :certifications
      true -> :unknown
    end
  end

  # Extract content for a specific section
  defp extract_section(sections, section_key) do
    case Map.get(sections, section_key) do
      nil -> nil
      content when content == "" -> nil
      content -> String.trim(content)
    end
  end
end
