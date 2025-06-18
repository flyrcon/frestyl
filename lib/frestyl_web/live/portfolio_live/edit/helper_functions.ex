# lib/frestyl_web/live/portfolio_live/edit/helper_functions.ex - COMPLETE FIXED VERSION

defmodule FrestylWeb.PortfolioLive.Edit.HelperFunctions do
  @moduledoc """
  FIXED: Enhanced helper functions for proper section content display with HTML stripping
  """
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3, push_navigate: 2]

  # ============================================================================
  # CRITICAL: HTML STRIPPING AND CONTENT CLEANING
  # ============================================================================

  def strip_html_from_content(content) when is_binary(content) do
    content
    |> String.replace(~r/<[^>]*>/, "")  # Remove HTML tags
    |> String.replace(~r/&nbsp;/, " ")  # Replace &nbsp; with spaces
    |> String.replace(~r/&amp;/, "&")   # Replace &amp; with &
    |> String.replace(~r/&lt;/, "<")    # Replace &lt; with <
    |> String.replace(~r/&gt;/, ">")    # Replace &gt; with >
    |> String.replace(~r/&quot;/, "\"") # Replace &quot; with "
    |> String.replace(~r/&#39;/, "'")   # Replace &#39; with '
    |> String.trim()
    |> String.replace(~r/\s+/, " ")     # Normalize whitespace
  end
  def strip_html_from_content(content), do: content

  # ============================================================================
  # FIXED: Enhanced section content summary that handles imported data properly
  # ============================================================================

  def get_section_content_summary(section) do
    content = section.content || %{}

    case section.section_type do
      # Handle Introduction sections
      type when type in [:intro, "intro"] ->
        cond do
          has_text_content?(content, "summary") ->
            content["summary"] |> strip_html_from_content() |> truncate_text(120)
          has_text_content?(content, "headline") ->
            content["headline"] |> strip_html_from_content()
          true ->
            get_fallback_content_summary(content)
        end

      # Handle Experience sections - FIXED to show clean content
      type when type in [:experience, "experience"] ->
        jobs = get_in(content, ["jobs"]) || []
        cond do
          length(jobs) > 0 ->
            first_job = List.first(jobs)
            title = Map.get(first_job, "title", "") |> strip_html_from_content()
            company = Map.get(first_job, "company", "") |> strip_html_from_content()
            if title != "" and company != "", do: "#{title} at #{company}", else: "#{length(jobs)} experience entries"
          true ->
            "No experience entries yet"
        end

      # Handle Skills sections
      type when type in [:skills, "skills"] ->
        skills = get_in(content, ["skills"]) || []
        skill_categories = get_in(content, ["skill_categories"]) || %{}

        cond do
          map_size(skill_categories) > 0 ->
            total_skills = skill_categories |> Map.values() |> List.flatten() |> length()
            category_count = map_size(skill_categories)
            "#{total_skills} skills in #{category_count} categories"
          length(skills) > 0 ->
            "#{length(skills)} skills listed"
          true ->
            "No skills added yet"
        end

      # Handle Education sections
      type when type in [:education, "education"] ->
        education = get_in(content, ["education"]) || []
        certifications = get_in(content, ["certifications"]) || []

        cond do
          length(education) > 0 ->
            first_edu = List.first(education)
            degree = Map.get(first_edu, "degree", "") |> strip_html_from_content()
            institution = Map.get(first_edu, "institution", "") |> strip_html_from_content()
            if degree != "" and institution != "", do: "#{degree} at #{institution}", else: "#{length(education)} education entries"
          length(certifications) > 0 ->
            "#{length(certifications)} certifications"
          true ->
            "No education entries yet"
        end

      # Handle Projects sections
      type when type in [:projects, "projects"] ->
        projects = get_in(content, ["projects"]) || []
        if length(projects) > 0 do
          first_project = List.first(projects)
          title = Map.get(first_project, "title", "") |> strip_html_from_content()
          if title != "", do: title, else: "#{length(projects)} projects"
        else
          "No projects added yet"
        end

      # Handle Featured Project sections
      type when type in [:featured_project, "featured_project"] ->
        title = get_in(content, ["title"]) || ""
        subtitle = get_in(content, ["subtitle"]) || ""
        cond do
          title != "" and subtitle != "" ->
            "#{strip_html_from_content(title)}: #{strip_html_from_content(subtitle)}"
          title != "" ->
            strip_html_from_content(title)
          subtitle != "" ->
            strip_html_from_content(subtitle)
          true ->
            get_fallback_content_summary(content)
        end

      # Handle Contact sections
      type when type in [:contact, "contact"] ->
        email = get_in(content, ["primary_email"]) || get_in(content, ["email"]) || ""
        phone = get_in(content, ["phone"]) || ""
        location = get_in(content, ["location"]) || ""

        contact_items = [email, phone, location]
        |> Enum.map(&strip_html_from_content/1)
        |> Enum.filter(&(&1 != ""))

        if length(contact_items) > 0 do
          "Contact: #{Enum.join(contact_items, " • ")}"
        else
          "No contact information yet"
        end

      # Handle Achievements sections
      type when type in [:achievements, "achievements"] ->
        achievements = get_in(content, ["achievements"]) || []
        if length(achievements) > 0 do
          first_achievement = List.first(achievements)
          title = Map.get(first_achievement, "title", "") |> strip_html_from_content()
          if title != "", do: title, else: "#{length(achievements)} achievements"
        else
          "No achievements added yet"
        end

      # Handle other section types
      _ ->
        get_fallback_content_summary(content)
    end
  end

  # ============================================================================
  # FIXED: Enhanced main content extraction for editing with HTML stripping
  # ============================================================================

  def get_section_main_content(section) do
    content = section.content || %{}

    case section.section_type do
      type when type in [:intro, "intro"] ->
        summary = get_in(content, ["summary"]) || ""
        headline = get_in(content, ["headline"]) || ""

        main_content = if summary != "", do: summary, else: headline
        strip_html_from_content(main_content)

      type when type in [:experience, "experience"] ->
        jobs = get_in(content, ["jobs"]) || []
        if length(jobs) > 0 do
          Enum.map_join(jobs, "\n\n", fn job ->
            format_job_for_editing_clean(job)
          end)
        else
          ""
        end

      type when type in [:skills, "skills"] ->
        skills = get_in(content, ["skills"]) || []
        skill_categories = get_in(content, ["skill_categories"]) || %{}

        if map_size(skill_categories) > 0 do
          format_categorized_skills_for_editing_clean(skill_categories)
        else
          Enum.map(skills, &strip_html_from_content/1) |> Enum.join(", ")
        end

      type when type in [:education, "education"] ->
        education = get_in(content, ["education"]) || []
        if length(education) > 0 do
          Enum.map_join(education, "\n\n", fn edu ->
            format_education_for_editing_clean(edu)
          end)
        else
          ""
        end

      type when type in [:projects, "projects"] ->
        projects = get_in(content, ["projects"]) || []
        if length(projects) > 0 do
          Enum.map_join(projects, "\n\n", fn project ->
            format_project_for_editing_clean(project)
          end)
        else
          ""
        end

      type when type in [:contact, "contact"] ->
        email = get_in(content, ["primary_email"]) || get_in(content, ["email"]) || ""
        phone = get_in(content, ["phone"]) || ""
        location = get_in(content, ["location"]) || ""

        [email, phone, location]
        |> Enum.map(&strip_html_from_content/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.join("\n")

      _ ->
        # For other section types, try to extract any meaningful text content
        get_fallback_main_content_clean(content)
    end
  end

  # ============================================================================
  # FIXED: Clean formatting functions that strip HTML
  # ============================================================================

  defp format_job_for_editing_clean(job) do
    title = Map.get(job, "title", "") |> strip_html_from_content()
    company = Map.get(job, "company", "") |> strip_html_from_content()
    description = Map.get(job, "description", "") |> strip_html_from_content()
    start_date = Map.get(job, "start_date", "") |> strip_html_from_content()
    end_date = Map.get(job, "end_date", "") |> strip_html_from_content()

    date_range = if start_date != "" do
      if end_date != "" and end_date != start_date do
        "#{start_date} - #{end_date}"
      else
        "#{start_date} - Present"
      end
    else
      ""
    end

    header = if title != "" and company != "" do
      "#{title} at #{company}"
    else
      title <> company
    end

    [header, date_range, description]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp format_education_for_editing_clean(edu) do
    degree = Map.get(edu, "degree", "") |> strip_html_from_content()
    field = Map.get(edu, "field", "") |> strip_html_from_content()
    institution = Map.get(edu, "institution", "") |> strip_html_from_content()
    description = Map.get(edu, "description", "") |> strip_html_from_content()

    header = cond do
      degree != "" and field != "" and institution != "" ->
        "#{degree} in #{field} - #{institution}"
      degree != "" and institution != "" ->
        "#{degree} - #{institution}"
      institution != "" ->
        institution
      true ->
        degree <> field
    end

    [header, description]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp format_project_for_editing_clean(project) do
    title = Map.get(project, "title", "") |> strip_html_from_content()
    description = Map.get(project, "description", "") |> strip_html_from_content()
    technologies = Map.get(project, "technologies", [])

    tech_string = if is_list(technologies) and length(technologies) > 0 do
      clean_technologies = Enum.map(technologies, &strip_html_from_content/1)
      "Technologies: #{Enum.join(clean_technologies, ", ")}"
    else
      ""
    end

    [title, description, tech_string]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp format_categorized_skills_for_editing_clean(skill_categories) do
    skill_categories
    |> Enum.map(fn {category, skills} ->
      skill_names = if is_list(skills) do
        Enum.map(skills, fn skill ->
          case skill do
            %{"name" => name} -> strip_html_from_content(name)
            skill_string when is_binary(skill_string) -> strip_html_from_content(skill_string)
            _ -> "Unknown"
          end
        end)
      else
        []
      end

      category_clean = strip_html_from_content(category)
      "#{category_clean}:\n#{Enum.join(skill_names, ", ")}"
    end)
    |> Enum.join("\n\n")
  end

  # ============================================================================
  # FIXED: Fallback content extraction with HTML stripping
  # ============================================================================

  defp get_fallback_content_summary(content) when is_map(content) do
    # Try common content keys in order of preference
    common_keys = ["summary", "description", "content", "headline", "title", "text"]

    found_content = Enum.find_value(common_keys, fn key ->
      case Map.get(content, key) do
        text when is_binary(text) and text != "" ->
          strip_html_from_content(text)
        _ -> nil
      end
    end)

    case found_content do
      nil ->
        # If no common keys found, try to extract any text content
        extract_any_text_content_clean(content)
      text ->
        truncate_text(text, 120)
    end
  end

  defp get_fallback_main_content_clean(content) when is_map(content) do
    # Try common content keys in order of preference for main content
    common_keys = ["content", "description", "summary", "text", "main_content"]

    Enum.find_value(common_keys, fn key ->
      case Map.get(content, key) do
        text when is_binary(text) and text != "" ->
          strip_html_from_content(text)
        _ -> nil
      end
    end) || ""
  end

  defp extract_any_text_content_clean(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.find_value(fn value ->
      case value do
        text when is_binary(text) ->
          cleaned = strip_html_from_content(text)
          trimmed = String.trim(cleaned)
          if trimmed != "", do: truncate_text(trimmed, 120), else: nil
        _ ->
          nil
      end
    end) || "No content available"
  end

  # FIXED: Add missing extract_any_text_content function for backward compatibility
  def extract_any_text_content(content) when is_map(content) do
    extract_any_text_content_clean(content)
  end

  # FIXED: Text content checking with HTML awareness
  defp has_text_content?(content, key) when is_map(content) do
    case Map.get(content, key) do
      text when is_binary(text) ->
        cleaned = strip_html_from_content(text)
        String.trim(cleaned) != ""
      _ -> false
    end
  end

  # ============================================================================
  # FIXED: Text truncation with proper word boundaries
  # ============================================================================

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) <= max_length do
      text
    else
      text
      |> String.slice(0, max_length)
      |> String.split(" ")
      |> Enum.drop(-1)
      |> Enum.join(" ")
      |> Kernel.<>("...")
    end
  end

  # ============================================================================
  # EXISTING HELPER FUNCTIONS (keeping all the existing ones with fixes)
  # ============================================================================

  # FIXED: Section media count helpers
  def get_section_media_count(section_id) do
    try do
      Frestyl.Portfolios.list_section_media(section_id) |> length()
    rescue
      _ -> 0
    end
  end

  def get_section_media_preview(section_id, limit \\ 4) do
    try do
      Frestyl.Portfolios.list_section_media(section_id)
      |> Enum.take(limit)
    rescue
      _ -> []
    end
  end

  # FIXED: Portfolio stats helpers
  def get_portfolio_view_count(portfolio) do
    try do
      Frestyl.Portfolios.get_total_visits(portfolio.id)
    rescue
      _ -> 0
    end
  end

  def get_portfolio_media_count(portfolio) do
    try do
      Frestyl.Portfolios.list_portfolio_media(portfolio.id) |> length()
    rescue
      _ -> 0
    end
  end

  # Existing helper functions (keep all the existing ones)
  def normalize_customization(customization) when is_map(customization) do
    customization
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {to_string(key), normalize_value(value)}
      {key, value} when is_binary(key) -> {key, normalize_value(value)}
    end)
    |> Enum.into(%{})
  end
  def normalize_customization(_), do: %{}

  def normalize_value(value) when is_map(value) do
    value
    |> Enum.map(fn
      {key, val} when is_atom(key) -> {to_string(key), normalize_value(val)}
      {key, val} when is_binary(key) -> {key, normalize_value(val)}
    end)
    |> Enum.into(%{})
  end
  def normalize_value(value), do: value

  def stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {to_string(key), stringify_keys(value)}
      {key, value} when is_binary(key) -> {key, stringify_keys(value)}
    end)
    |> Enum.into(%{})
  end
  def stringify_keys(value), do: value

  def get_current_primary_color(customization) do
    normalized = stringify_keys(customization || %{})
    Map.get(normalized, "primary_color", "#6366f1")
  end

  def format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      "intro" -> "Introduction"
      :experience -> "Work Experience"
      "experience" -> "Work Experience"
      :education -> "Education"
      "education" -> "Education"
      :skills -> "Skills & Expertise"
      "skills" -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      "featured_project" -> "Featured Project"
      :case_study -> "Case Study"
      "case_study" -> "Case Study"
      :media_showcase -> "Media Showcase"
      "media_showcase" -> "Media Showcase"
      :testimonial -> "Testimonials"
      "testimonial" -> "Testimonials"
      :contact -> "Contact Information"
      "contact" -> "Contact Information"
      :projects -> "Projects"
      "projects" -> "Projects"
      :achievements -> "Achievements"
      "achievements" -> "Achievements"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end

  def get_section_emoji(section_type) do
    case section_type do
      type when type in [:intro, "intro"] -> "👋"
      type when type in [:experience, "experience"] -> "💼"
      type when type in [:education, "education"] -> "🎓"
      type when type in [:skills, "skills"] -> "⚡"
      type when type in [:projects, "projects"] -> "🛠️"
      type when type in [:featured_project, "featured_project"] -> "🚀"
      type when type in [:case_study, "case_study"] -> "📊"
      type when type in [:achievements, "achievements"] -> "🏆"
      type when type in [:testimonial, "testimonial"] -> "💬"
      type when type in [:media_showcase, "media_showcase"] -> "🖼️"
      type when type in [:code_showcase, "code_showcase"] -> "💻"
      type when type in [:contact, "contact"] -> "📧"
      type when type in [:custom, "custom"] -> "🎨"
      _ -> "📄"
    end
  end

  # Date formatting helpers
  def format_relative_time(datetime) do
    current_time = DateTime.utc_now()

    # Convert NaiveDateTime to DateTime if needed
    datetime_utc = case datetime do
      %DateTime{} -> datetime
      %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
      _ -> current_time
    end

    case DateTime.diff(current_time, datetime_utc, :second) do
      diff when diff < 60 -> "Just now"
      diff when diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff when diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff when diff < 604800 -> "#{div(diff, 86400)} days ago"
      _ -> Calendar.strftime(datetime_utc, "%b %d, %Y")
    end
  rescue
    _ -> "Unknown time"
  end

  def format_date(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      %NaiveDateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      _ -> "Unknown date"
    end
  rescue
    _ -> "Unknown date"
  end

  # File size formatting
  def format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  def format_file_size(_), do: "Unknown size"

  # Theme and styling helpers
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

  # FIXED: Additional portfolio management helpers with meaningful content check
  def get_portfolio_section_count(portfolio_id) do
    try do
      Frestyl.Portfolios.list_portfolio_sections(portfolio_id) |> length()
    rescue
      _ -> 0
    end
  end

  def get_portfolio_completion_percentage(portfolio) do
    sections = Frestyl.Portfolios.list_portfolio_sections(portfolio.id)

    if length(sections) == 0 do
      25 # Base portfolio exists
    else
      base_score = 25
      section_score = min(50, length(sections) * 10) # 10 points per section, max 50
      content_score = calculate_content_completeness(sections) # Max 25 points

      base_score + section_score + content_score
    end
  end

  defp calculate_content_completeness(sections) do
    if length(sections) == 0 do
      0
    else
      total_sections = length(sections)
      completed_sections = Enum.count(sections, fn section ->
        content = section.content || %{}
        has_meaningful_content?(content, section.section_type)
      end)

      round((completed_sections / total_sections) * 25)
    end
  end

  defp has_meaningful_content?(content, section_type) when is_map(content) do
    case section_type do
      type when type in [:intro, "intro"] ->
        has_text_content?(content, "summary") or has_text_content?(content, "headline")

      type when type in [:experience, "experience"] ->
        jobs = Map.get(content, "jobs", [])
        is_list(jobs) and length(jobs) > 0

      type when type in [:skills, "skills"] ->
        skills = Map.get(content, "skills", [])
        skill_categories = Map.get(content, "skill_categories", %{})
        (is_list(skills) and length(skills) > 0) or (is_map(skill_categories) and map_size(skill_categories) > 0)

      type when type in [:education, "education"] ->
        education = Map.get(content, "education", [])
        is_list(education) and length(education) > 0

      type when type in [:projects, "projects"] ->
        projects = Map.get(content, "projects", [])
        is_list(projects) and length(projects) > 0

      type when type in [:contact, "contact"] ->
        email = Map.get(content, "email", "") || Map.get(content, "primary_email", "")
        phone = Map.get(content, "phone", "")
        email != "" or phone != ""

      _ ->
        # For other section types, check for any meaningful text content
        extract_any_text_content_clean(content) != "No content available"
    end
  end

  # Additional utility functions for completeness
  def get_next_section_position(portfolio_id) do
    try do
      case Frestyl.Portfolios.list_portfolio_sections(portfolio_id) do
        [] -> 1
        sections -> Enum.map(sections, & &1.position) |> Enum.max() |> Kernel.+(1)
      end
    rescue
      _ -> 1
    end
  end

  def get_user_friendly_error(error) when is_binary(error), do: error
  def get_user_friendly_error(:file_too_large), do: "File is too large. Please choose a smaller file."
  def get_user_friendly_error(:invalid_file_type), do: "File type not supported. Please choose a different file."
  def get_user_friendly_error(:upload_failed), do: "Upload failed. Please try again."
  def get_user_friendly_error(:processing_failed), do: "File processing failed. Please try again."
  def get_user_friendly_error(:storage_error), do: "Unable to save file. Please try again."
  def get_user_friendly_error(_), do: "An unexpected error occurred. Please try again."

  # Content sanitization helpers
  def sanitize_content(content) when is_binary(content) do
    content
    |> String.trim()
    |> String.replace(~r/\r\n|\r/, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  def sanitize_content(content), do: content
end
