# lib/frestyl_web/live/portfolio_live/edit/helper_functions.ex
defmodule FrestylWeb.PortfolioLive.Edit.HelperFunctions do
  @moduledoc """
  Shared helper functions for portfolio editing functionality.
  Includes data normalization, formatting, and utility functions.
  """
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3, push_navigate: 2]

  @doc """
  Normalizes customization data to use string keys consistently
  """
  def normalize_customization(customization) when is_map(customization) do
    customization
    |> Enum.map(fn
      # Convert atom keys to strings
      {key, value} when is_atom(key) -> {to_string(key), normalize_value(value)}
      # Keep string keys as-is but normalize values
      {key, value} when is_binary(key) -> {key, normalize_value(value)}
    end)
    |> Enum.into(%{})
  end

  def normalize_customization(_), do: %{}

  @doc """
  Normalizes nested values in customization
  """
  def normalize_value(value) when is_map(value) do
    value
    |> Enum.map(fn
      {key, val} when is_atom(key) -> {to_string(key), normalize_value(val)}
      {key, val} when is_binary(key) -> {key, normalize_value(val)}
    end)
    |> Enum.into(%{})
  end

  def normalize_value(value), do: value

  @doc """
  Converts ALL keys to strings recursively
  """
  def stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {to_string(key), stringify_keys(value)}
      {key, value} when is_binary(key) -> {key, stringify_keys(value)}
    end)
    |> Enum.into(%{})
  end

  def stringify_keys(value), do: value

  @doc """
  Gets the current primary color from customization
  """
  def get_current_primary_color(customization) do
    normalized = stringify_keys(customization || %{})
    Map.get(normalized, "primary_color", "#6366f1")
  end

  @doc """
  Formats section types for display
  """
  def format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media Showcase"
      :testimonial -> "Testimonials"
      :contact -> "Contact Information"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end

  def get_section_type_icon(section_type) do
    case section_type do
      :intro -> "👋"
      :experience -> "💼"
      :education -> "🎓"
      :skills -> "⚡"
      :projects -> "🚀"
      :contact -> "📞"
      :achievements -> "🏆"
      :testimonial -> "💬"
      :media_showcase -> "🖼️"
      :code_showcase -> "💻"
      _ -> "📝"
    end
  end

  @doc """
  Gets emoji for section types
  """
  def get_section_emoji(section_type) do
    case section_type do
      :intro -> "👋"
      "intro" -> "👋"
      :experience -> "💼"
      "experience" -> "💼"
      :education -> "🎓"
      "education" -> "🎓"
      :skills -> "⚡"
      "skills" -> "⚡"
      :projects -> "🛠️"
      "projects" -> "🛠️"
      :featured_project -> "🚀"
      "featured_project" -> "🚀"
      :case_study -> "📊"
      "case_study" -> "📊"
      :achievements -> "🏆"
      "achievements" -> "🏆"
      :testimonial -> "💬"
      "testimonial" -> "💬"
      :media_showcase -> "🖼️"
      "media_showcase" -> "🖼️"
      :code_showcase -> "💻"
      "code_showcase" -> "💻"
      :contact -> "📧"
      "contact" -> "📧"
      :custom -> "🎨"
      "custom" -> "🎨"
      _ -> "📄"
    end
  end

  @doc """
  Gets a brief summary of section content
  """
  def get_section_content_summary(section) do
    content = section.content || %{}

    cond do
      Map.has_key?(content, "summary") && content["summary"] != "" ->
        String.slice(content["summary"], 0, 100) <> "..."

      Map.has_key?(content, "description") && content["description"] != "" ->
        String.slice(content["description"], 0, 100) <> "..."

      Map.has_key?(content, "headline") && content["headline"] != "" ->
        content["headline"]

      Map.has_key?(content, "jobs") && is_list(content["jobs"]) ->
        "#{length(content["jobs"])} job entries"

      Map.has_key?(content, "projects") && is_list(content["projects"]) ->
        "#{length(content["projects"])} projects"

      Map.has_key?(content, "skills") && is_list(content["skills"]) ->
        "#{length(content["skills"])} skills"

      Map.has_key?(content, "education") && is_list(content["education"]) ->
        "#{length(content["education"])} education entries"

      true ->
        "Click to add content"
    end
  end

  @doc """
  Safely gets nested content from maps
  """
  def get_nested_content(content, keys) when is_map(content) and is_list(keys) do
    get_in(content, keys)
  end

  def get_nested_content(_, _), do: nil

  @doc """
  Formats file sizes for display
  """
  def format_file_size(size) when size > 1_048_576 do
    "#{Float.round(size / 1_048_576, 1)} MB"
  end

  def format_file_size(size) when size > 1024 do
    "#{Float.round(size / 1024, 1)} KB"
  end

  def format_file_size(size) do
    "#{size} bytes"
  end

  @doc """
  Formats dates for display
  """
  def format_date(datetime) do
    case datetime do
      %DateTime{} ->
        Calendar.strftime(datetime, "%b %d, %Y")
      _ ->
        "Unknown"
    end
  end

  @doc """
  Gets portfolio view count
  """
  def get_portfolio_view_count(portfolio) do
    case Frestyl.Portfolios.get_portfolio_analytics(portfolio.id, portfolio.user_id) do
      %{total_visits: count} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end

  @doc """
  Gets portfolio media count
  """
  def get_portfolio_media_count(portfolio) do
    try do
      Frestyl.Portfolios.list_portfolio_media(portfolio.id) |> length()
    rescue
      _ -> 0
    end
  end

  @doc """
  Validates media types
  """
  def valid_media_type?(mime_type) do
    allowed_types = [
      # Images
      "image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp",
      # Videos
      "video/mp4", "video/quicktime", "video/webm", "video/avi",
      # Audio
      "audio/mpeg", "audio/mp3", "audio/wav", "audio/ogg", "audio/aac",
      # Documents
      "application/pdf", "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "text/plain"
    ]

    mime_type in allowed_types
  end

  @doc """
  Determines media type from content type
  """
  def determine_media_type(content_type) do
    cond do
      String.starts_with?(content_type, "image/") -> "image"
      String.starts_with?(content_type, "video/") -> "video"
      String.starts_with?(content_type, "audio/") -> "audio"
      true -> "document"
    end
  end

  @doc """
  Gets file type icon
  """
  def get_file_type_icon(mime_type) do
    case mime_type do
      "image/" <> _ -> "🖼️"
      "video/" <> _ -> "🎥"
      "audio/" <> _ -> "🎵"
      "application/pdf" -> "📄"
      "text/" <> _ -> "📝"
      _ -> "📎"
    end
  end

  @doc """
  Gets file type label
  """
  def get_file_type_label(mime_type) do
    case mime_type do
      "image/" <> _ -> "Image"
      "video/" <> _ -> "Video"
      "audio/" <> _ -> "Audio"
      "application/pdf" -> "PDF"
      "text/" <> _ -> "Text"
      _ -> "Document"
    end
  end

  @doc """
  Converts upload errors to strings
  """
  def error_to_string(:too_large), do: "File is too large"
  def error_to_string(:not_accepted), do: "File type not supported"
  def error_to_string(:too_many_files), do: "Too many files selected"
  def error_to_string(:external_client_failure), do: "Upload failed"
  def error_to_string(error), do: "Upload error: #{inspect(error)}"

  @doc """
  Gets next section position
  """
  def get_next_section_position(portfolio_id) do
    sections = Frestyl.Portfolios.list_portfolio_sections(portfolio_id)
    case sections do
      [] -> 1
      sections -> Enum.map(sections, & &1.position) |> Enum.max() |> Kernel.+(1)
    end
  end

  @doc """
  Gets next media position for a section
  """
  def get_next_media_position(section_id) do
    try do
      case Frestyl.Portfolios.list_section_media(section_id) do
        [] -> 0
        media_list when is_list(media_list) ->
          max_position = Enum.max_by(media_list, & &1.position, fn -> %{position: -1} end).position
          max_position + 1
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  @doc """
  Extracts main content from section for editing
  """
  def get_section_main_content(section) do
    case section.section_type do
      :intro ->
        summary = get_nested_content(section.content, ["summary"]) || ""
        headline = get_nested_content(section.content, ["headline"]) || ""
        if String.length(headline) > 0 and String.length(summary) > 0 do
          "#{headline}\n\n#{summary}"
        else
          headline <> summary
        end

      :experience ->
        jobs = get_nested_content(section.content, ["jobs"]) || []
        if length(jobs) > 0 do
          Enum.map_join(jobs, "\n\n", fn job ->
            title = Map.get(job, "title", "")
            company = Map.get(job, "company", "")
            description = Map.get(job, "description", "")
            "#{title} at #{company}\n#{description}"
          end)
        else
          ""
        end

      :contact ->
        email = get_nested_content(section.content, ["email"]) || ""
        phone = get_nested_content(section.content, ["phone"]) || ""
        location = get_nested_content(section.content, ["location"]) || ""
        [email, phone, location] |> Enum.filter(&(String.length(&1) > 0)) |> Enum.join("\n")

      _ ->
        # For other section types, try to extract any text content
        case section.content do
          %{"content" => content} when is_binary(content) -> content
          %{"description" => desc} when is_binary(desc) -> desc
          %{"summary" => summary} when is_binary(summary) -> summary
          _ -> ""
        end
    end
  end

  @doc """
  Gets theme classes for styling
  """
  def get_theme_classes(customization, portfolio) do
    theme = portfolio.theme || "executive"
    primary_color = get_in(customization, ["primary_color"]) || "#6366f1"

    %{
      theme: theme,
      primary_color: primary_color,
      css_vars: """
      :root {
        --portfolio-primary: #{primary_color};
        --portfolio-secondary: #{get_in(customization, ["secondary_color"]) || "#8b5cf6"};
        --portfolio-accent: #{get_in(customization, ["accent_color"]) || "#f59e0b"};
      }
      """
    }
  end

  defp font_class(font_style) do
    case font_style do
      "inter" -> "font-sans"
      "merriweather" -> "font-serif"
      "roboto" -> "font-mono"
      "playfair" -> "font-serif"
      _ -> "font-sans"
    end
  end

  defp spacing_class(spacing) do
    case spacing do
      "compact" -> "space-y-4"
      "normal" -> "space-y-6"
      "spacious" -> "space-y-8"
      _ -> "space-y-6"
    end
  end

    def get_next_section_position(portfolio_id) do
    case Portfolios.get_max_section_position(portfolio_id) do
      nil -> 1
      max_position -> max_position + 1
    end
  end

  def get_next_media_position(section_id) do
    case Portfolios.get_max_media_position(section_id) do
      nil -> 1
      max_position -> max_position + 1
    end
  end

  def get_section_content_summary(section) do
    case section.content do
      %{"headline" => headline} when is_binary(headline) and headline != "" ->
        String.slice(headline, 0, 100)

      %{"description" => description} when is_binary(description) and description != "" ->
        String.slice(description, 0, 100)

      %{"main_content" => content} when is_binary(content) and content != "" ->
        String.slice(content, 0, 100)

      %{"title" => title} when is_binary(title) and title != "" ->
        String.slice(title, 0, 100)

      content when is_map(content) ->
        # Try to find any text content
        content
        |> Map.values()
        |> Enum.find(&(is_binary(&1) and String.trim(&1) != ""))
        |> case do
          nil -> "No content yet"
          text -> String.slice(text, 0, 100)
        end

      _ ->
        "No content yet"
    end
  end

  def get_section_main_content(section) do
    case section.content do
      %{"main_content" => content} when is_binary(content) -> content
      %{"description" => content} when is_binary(content) -> content
      %{"summary" => content} when is_binary(content) -> content
      _ -> ""
    end
  end

    def format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      "intro" -> "Introduction"
      :experience -> "Experience"
      "experience" -> "Experience"
      :education -> "Education"
      "education" -> "Education"
      :skills -> "Skills"
      "skills" -> "Skills"
      :projects -> "Projects"
      "projects" -> "Projects"
      :featured_project -> "Featured Project"
      "featured_project" -> "Featured Project"
      :case_study -> "Case Study"
      "case_study" -> "Case Study"
      :achievements -> "Achievements"
      "achievements" -> "Achievements"
      :testimonial -> "Testimonial"
      "testimonial" -> "Testimonial"
      :media_showcase -> "Media Gallery"
      "media_showcase" -> "Media Gallery"
      :code_showcase -> "Code Showcase"
      "code_showcase" -> "Code Showcase"
      :contact -> "Contact"
      "contact" -> "Contact"
      :custom -> "Custom"
      "custom" -> "Custom"
      atom when is_atom(atom) -> atom |> Atom.to_string() |> String.capitalize()
      string when is_binary(string) -> String.capitalize(string)
      _ -> "Section"
    end
  end

  def format_section_type(section_type) when is_atom(section_type) do
    section_type |> to_string() |> format_section_type()
  end

  def format_section_type(section_type) when is_binary(section_type) do
    section_type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def get_section_emoji(section_type) do
    case section_type do
      :intro -> "👋"
      "intro" -> "👋"
      :experience -> "💼"
      "experience" -> "💼"
      :education -> "🎓"
      "education" -> "🎓"
      :skills -> "⚡"
      "skills" -> "⚡"
      :projects -> "🛠️"
      "projects" -> "🛠️"
      :featured_project -> "🚀"
      "featured_project" -> "🚀"
      :case_study -> "📊"
      "case_study" -> "📊"
      :achievements -> "🏆"
      "achievements" -> "🏆"
      :testimonial -> "💬"
      "testimonial" -> "💬"
      :media_showcase -> "🖼️"
      "media_showcase" -> "🖼️"
      :code_showcase -> "💻"
      "code_showcase" -> "💻"
      :contact -> "📧"
      "contact" -> "📧"
      :custom -> "🎨"
      "custom" -> "🎨"
      _ -> "📄"
    end
  end

  # ============================================================================
  # PHASE 4: NEW MEDIA MANAGEMENT HELPERS
  # ============================================================================

  def valid_media_type?(mime_type) do
    allowed_types = [
      # Images
      "image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp", "image/svg+xml",
      # Videos
      "video/mp4", "video/mov", "video/avi", "video/webm", "video/quicktime",
      # Audio
      "audio/mp3", "audio/wav", "audio/ogg", "audio/mpeg",
      # Documents
      "application/pdf", "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "text/plain", "text/markdown", "application/rtf"
    ]

    mime_type in allowed_types
  end

  def determine_media_type(mime_type) do
    cond do
      String.starts_with?(mime_type, "image/") -> "image"
      String.starts_with?(mime_type, "video/") -> "video"
      String.starts_with?(mime_type, "audio/") -> "audio"
      mime_type in ["application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain", "text/markdown", "application/rtf"] -> "document"
      true -> "file"
    end
  end

  def format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
    end
  end

  def format_file_size(_), do: "Unknown size"

  def get_section_media_count(section) do
    try do
      case section do
        %{id: section_id} when is_integer(section_id) ->
          # Count media items for this section
          Frestyl.Portfolios.list_section_media(section_id) |> length()

        _ ->
          0
      end
    rescue
      _ -> 0
    end
  end

  def get_section_media_preview(section, _opts \\ []) do
    try do
      case section do
        %{id: section_id} when is_integer(section_id) ->
          # Get first few media items as preview
          Frestyl.Portfolios.list_section_media(section_id)
          |> Enum.take(3)
          |> Enum.map(fn media ->
            %{
              id: media.id,
              title: media.title || "Untitled",
              media_type: media.media_type || "image",
              file_path: media.file_path
            }
          end)

        _ ->
          []
      end
    rescue
      _ -> []
    end
  end

  def get_portfolio_media_count(portfolio) do
    Portfolios.get_portfolio_media_count(portfolio.id)
  end

  def get_portfolio_view_count(portfolio) do
    try do
      Frestyl.Portfolios.get_total_visits(portfolio.id)
    rescue
      _ -> 0
    end
  end

  def format_media_size(size) when is_integer(size) do
    cond do
      size > 1_000_000 -> "#{Float.round(size / 1_000_000, 1)} MB"
      size > 1_000 -> "#{Float.round(size / 1_000, 1)} KB"
      true -> "#{size} B"
    end
  end

  def format_media_size(_), do: "Unknown"

  def get_media_icon(media_type) do
    case media_type do
      "image" -> "📷"
      "video" -> "🎥"
      "document" -> "📄"
      "pdf" -> "📋"
      _ -> "📎"
    end
  end

  # ============================================================================
  # FORMATTING AND DISPLAY HELPERS
  # ============================================================================

  def format_date(date) when is_nil(date), do: "Never"

  def format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  def format_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_date()
  end

  def format_date(_), do: "Unknown"

  def format_relative_time(datetime) when is_nil(datetime), do: "never"

  def format_relative_time(datetime) do
    now = DateTime.utc_now()

    # Convert to DateTime if it's a NaiveDateTime
    datetime_utc = case datetime do
      %DateTime{} = dt -> dt
      %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
      _ -> DateTime.utc_now()  # fallback for any other type
    end

    diff = DateTime.diff(now, datetime_utc, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      true -> "#{div(diff, 604800)} weeks ago"
    end
  end

  def format_relative_time(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_relative_time()
  end

  def format_relative_time(_), do: "unknown"

  # ============================================================================
  # THEME AND STYLING HELPERS
  # ============================================================================

  def get_theme_classes(customization, portfolio) do
    base_classes = "portfolio-theme portfolio-#{portfolio.theme || "default"}"

    custom_classes = case customization do
      %{"custom_css_classes" => classes} when is_binary(classes) ->
        " #{classes}"
      _ ->
        ""
    end

    base_classes <> custom_classes
  end

  # ============================================================================
  # VALIDATION HELPERS
  # ============================================================================

  def validate_media_file(entry) do
    errors = []

    # Check file size (example: 50MB limit)
    errors = if entry.client_size > 50 * 1024 * 1024 do
      ["File is too large (max 50MB)" | errors]
    else
      errors
    end

    # Check file type
    errors = if not valid_media_type?(entry.client_type) do
      ["Unsupported file type: #{entry.client_type}" | errors]
    else
      errors
    end

    # Check filename length
    errors = if String.length(entry.client_name) > 255 do
      ["Filename is too long" | errors]
    else
      errors
    end

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  def safe_string_slice(nil, _start, _length), do: ""
  def safe_string_slice("", _start, _length), do: ""
  def safe_string_slice(string, start, length) when is_binary(string) do
    String.slice(string, start, length)
  end
  def safe_string_slice(_, _start, _length), do: ""

  def truncate_text(text, max_length \\ 100) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  def normalize_filename(filename) do
    filename
    |> String.replace(~r/[^a-zA-Z0-9._-]/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  def generate_unique_filename(original_filename) do
    timestamp = System.unique_integer([:positive])
    extension = Path.extname(original_filename)
    base_name = Path.basename(original_filename, extension)
    safe_base = normalize_filename(base_name)

    "#{timestamp}_#{safe_base}#{extension}"
  end

  # ============================================================================
  # CONTENT PROCESSING HELPERS
  # ============================================================================

  def extract_text_from_content(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  def extract_text_from_content(content) when is_binary(content), do: content
  def extract_text_from_content(_), do: ""

  def calculate_reading_time(text) when is_binary(text) do
    word_count = text |> String.split() |> length()
    # Average reading speed: 200 words per minute
    reading_time = max(1, div(word_count, 200))

    if reading_time == 1 do
      "1 min read"
    else
      "#{reading_time} min read"
    end
  end

  def calculate_reading_time(_), do: "0 min read"

  # ============================================================================
  # ERROR HANDLING HELPERS
  # ============================================================================

  def format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  def handle_upload_error(error) do
    case error do
      :too_large -> "File is too large"
      :too_many_files -> "Too many files selected"
      :not_accepted -> "File type not supported"
      :external_client_failure -> "Upload failed - please try again"
      _ -> "Upload error occurred"
    end
  end

  def get_section_main_content(section) do
    case section.content do
      %{"main_content" => content} when is_binary(content) -> content
      %{"content" => content} when is_binary(content) -> content
      %{"summary" => content} when is_binary(content) -> content
      %{"description" => content} when is_binary(content) -> content
      _ -> ""
    end
  end

  # Also add this helper for the relative time formatting:
  def format_relative_time(datetime) do
    case datetime do
      %DateTime{} = dt ->
        diff = DateTime.diff(DateTime.utc_now(), dt, :second)
        cond do
          diff < 60 -> "Just now"
          diff < 3600 -> "#{div(diff, 60)} minutes ago"
          diff < 86400 -> "#{div(diff, 3600)} hours ago"
          diff < 604800 -> "#{div(diff, 86400)} days ago"
          true -> Calendar.strftime(dt, "%B %d, %Y")
        end

      %NaiveDateTime{} = dt ->
        # Convert to DateTime assuming UTC
        dt
        |> DateTime.from_naive!("Etc/UTC")
        |> format_relative_time()

      _ -> "Unknown"
    end
  end
end
