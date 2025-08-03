# lib/frestyl_web/live/portfolio_live/components/enhanced_section_renderer.ex
# PART 1: Core Module, Safety Functions, and Main Routing

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer do
  @moduledoc """
  Enhanced section renderer with safe {:safe, content} handling and professional design.

  KEY FEATURES:
  - Clean, minimalist design with no borders
  - Enhanced skills with color-coded proficiency indicators
  - User color scheme integration with variety colors
  - Safe content extraction from {:safe, content} tuples
  - Zero Enum.join() calls - pure string concatenation only
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.EnhancedSectionSystem
  import Phoenix.HTML, only: [html_escape: 1, raw: 1]

  # ============================================================================
  # SAFE CONTENT EXTRACTION - Handles ALL {:safe, content} cases
  # ============================================================================

  # SAFE EXTRACTION - The complete solution for {:safe, content} tuples
  defp safe_extract(value) do
    case value do
      {:safe, content} when is_binary(content) ->
        String.trim(content)
      {:safe, content} when is_list(content) ->
        # Convert list to string safely - NO Enum.join!
        list_to_string_safe(content, "")
      {:safe, content} ->
        # Unknown safe content - inspect safely
        inspect(content)
      value when is_binary(value) ->
        String.trim(value)
      value when is_nil(value) ->
        ""
      value when is_atom(value) ->
        Atom.to_string(value)
      value when is_integer(value) ->
        Integer.to_string(value)
      value when is_float(value) ->
        Float.to_string(value)
      value ->
        # Last resort - inspect it
        inspect(value)
    end
  end

  # SAFE LIST TO STRING - NO Enum.join() allowed!
  defp list_to_string_safe([], acc), do: String.trim(acc)
  defp list_to_string_safe([head | tail], acc) when is_binary(head) do
    list_to_string_safe(tail, acc <> head)
  end
  defp list_to_string_safe([head | tail], acc) do
    # Convert non-binary to string safely
    head_str = case head do
      {:safe, content} when is_binary(content) -> content
      {:safe, content} when is_list(content) -> list_to_string_safe(content, "")
      other -> inspect(other)
    end
    list_to_string_safe(tail, acc <> head_str)
  end

  # SAFE MAP GET - Ultra defensive
  defp safe_map_get(map, key, default \\ "")
  defp safe_map_get(map, key, default) when is_map(map) do
    case Map.get(map, key, default) do
      value -> safe_extract(value)
    end
  end
  defp safe_map_get(_, _, default), do: safe_extract(default)

  # SAFE BOOLEAN - Check if not empty
  defp safe_not_empty?(value) do
    clean_value = safe_extract(value)
    clean_value != "" and clean_value != nil
  end

  # SAFE HTML ESCAPE - Handles {:safe, content} from html_escape()
  defp safe_html_escape(value) do
    try do
      case value do
        {:safe, content} when is_binary(content) ->
          content
        {:safe, content} when is_list(content) ->
          list_to_string_safe(content, "")
        {:safe, content} ->
          inspect(content)
        value when is_binary(value) ->
          # html_escape returns {:safe, content} - handle it!
          case html_escape(value) do
            {:safe, escaped_content} when is_binary(escaped_content) -> escaped_content
            {:safe, escaped_content} when is_list(escaped_content) -> list_to_string_safe(escaped_content, "")
            escaped_content when is_binary(escaped_content) -> escaped_content
            _ -> "HTML Error"
          end
        value when is_nil(value) ->
          ""
        value when is_atom(value) ->
          case html_escape(Atom.to_string(value)) do
            {:safe, escaped_content} when is_binary(escaped_content) -> escaped_content
            {:safe, escaped_content} when is_list(escaped_content) -> list_to_string_safe(escaped_content, "")
            escaped_content when is_binary(escaped_content) -> escaped_content
            _ -> "HTML Error"
          end
        value when is_integer(value) ->
          case html_escape(Integer.to_string(value)) do
            {:safe, escaped_content} when is_binary(escaped_content) -> escaped_content
            {:safe, escaped_content} when is_list(escaped_content) -> list_to_string_safe(escaped_content, "")
            escaped_content when is_binary(escaped_content) -> escaped_content
            _ -> "HTML Error"
          end
        value when is_float(value) ->
          case html_escape(Float.to_string(value)) do
            {:safe, escaped_content} when is_binary(escaped_content) -> escaped_content
            {:safe, escaped_content} when is_list(escaped_content) -> list_to_string_safe(escaped_content, "")
            escaped_content when is_binary(escaped_content) -> escaped_content
            _ -> "HTML Error"
          end
        value ->
          case html_escape(inspect(value)) do
            {:safe, escaped_content} when is_binary(escaped_content) -> escaped_content
            {:safe, escaped_content} when is_list(escaped_content) -> list_to_string_safe(escaped_content, "")
            escaped_content when is_binary(escaped_content) -> escaped_content
            _ -> "HTML Error"
          end
      end
    rescue
      _error ->
        "Safe Content Error"
    end
  end

  # CLEAN CONTENT - Deep clean all {:safe, content} tuples
  defp clean_content(data) do
    case data do
      {:safe, content} when is_binary(content) ->
        String.trim(content)
      {:safe, content} when is_list(content) ->
        list_to_string_safe(content, "")
      {:safe, content} ->
        inspect(content)
      data when is_map(data) ->
        # Clean each map value recursively
        clean_map_recursive(data, %{})
      data when is_list(data) ->
        # Clean each list item recursively
        clean_list_recursive(data, [])
      data ->
        data
    end
  end

  # RECURSIVE MAP CLEANER - NO Enum.map or Enum.into!
  defp clean_map_recursive(map, acc) when map_size(map) == 0, do: acc
  defp clean_map_recursive(map, acc) do
    {key, value} = Map.to_list(map) |> List.first()
    remaining_map = Map.delete(map, key)
    cleaned_value = clean_content(value)
    new_acc = Map.put(acc, key, cleaned_value)
    clean_map_recursive(remaining_map, new_acc)
  end

  # RECURSIVE LIST CLEANER - NO Enum.map!
  defp clean_list_recursive([], acc), do: Enum.reverse(acc)
  defp clean_list_recursive([head | tail], acc) do
    cleaned_head = clean_content(head)
    clean_list_recursive(tail, [cleaned_head | acc])
  end

  def render(assigns) do
    ~H"""
    <div class="portfolio-section-container"
         data-section-type={@section.section_type}
         data-section-id={@section.id}>

      <!-- Section Header -->
      <div class="section-header mb-4">
        <div class="flex items-center justify-between">
          <div class="header-info">
            <h3 class="text-xl font-bold text-gray-900 mb-1"><%= @section.title %></h3>
          </div>

          <%= if Map.get(assigns, :show_actions, false) do %>
            <div class="header-actions flex items-center space-x-2">
              <button phx-click="edit_section"
                      phx-value-section_id={@section.id}
                      class="p-2 text-gray-500 hover:text-gray-700 rounded-lg hover:bg-gray-100 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <!-- CONSISTENT SECTION CONTAINER - No borders, clean design -->
      <div class="section-content-container max-h-80 overflow-y-auto">
        <div class="space-y-3">
          <%= render_section_content(@section, assigns) %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MAIN CONTENT ROUTING - Safe Functions
  # ============================================================================

  def render_section_content_static(section, customization \\ %{}) do
    # STEP 1: Safe type extraction
    section_type_str = try do
      safe_extract(section.section_type)
    rescue
      error ->
        IO.puts("❌ Error extracting section type: #{inspect(error)}")
        "unknown"
    end

    section_title = try do
      safe_extract(section.title)
    rescue
      error ->
        IO.puts("❌ Error extracting section title: #{inspect(error)}")
        "Unknown Section"
    end

    # STEP 2: Clean content
    raw_content = section.content || %{}
    clean_content_data = try do
      clean_content(raw_content)
    rescue
      error ->
        IO.puts("❌ Error cleaning content: #{inspect(error)}")
        %{}
    end

    # STEP 3: Route to specific renderer with maximum protection
    result = try do
      case section_type_str do
        "skills" ->
          render_skills_content_safe(clean_content_data, customization)
        "projects" ->
          render_projects_content_safe(clean_content_data, customization)
        "experience" ->
          render_experience_content_safe(clean_content_data, customization)
        "work_experience" ->
          render_experience_content_safe(clean_content_data, customization)
        "contact" ->
          render_contact_content_safe(clean_content_data, customization)
        "education" ->
          render_education_content_safe(clean_content_data, customization)
        "intro" ->
          render_intro_content_safe(clean_content_data, customization)
        "about" ->
          render_intro_content_safe(clean_content_data, customization)
        "story" ->
          render_intro_content_safe(clean_content_data, customization)
        "hero" ->
          render_intro_content_safe(clean_content_data, customization)
        "summary" ->
          render_intro_content_safe(clean_content_data, customization)
        "profile" ->
          render_intro_content_safe(clean_content_data, customization)
        "portfolio" ->
          render_projects_content_safe(clean_content_data, customization)
        "work" ->
          render_projects_content_safe(clean_content_data, customization)
        "certifications" ->
          render_education_content_safe(clean_content_data, customization)
        "achievements" ->
          render_achievements_section_safe(clean_content_data, customization)
        "awards" ->
          render_achievements_section_safe(clean_content_data, customization)
        _ ->
          render_generic_content_safe(clean_content_data, customization)
      end
    rescue
      error ->
        IO.puts("❌ CAUGHT THE ERROR! Section: " <> section_type_str)
        IO.puts("❌ Error details: #{inspect(error)}")

        # Return safe HTML using pure string concatenation
        html = "<div class=\"p-4 bg-red-100 rounded-lg\">"
        html = html <> "<h3 class=\"font-semibold text-red-900\">SECTION RENDERING ERROR</h3>"
        html = html <> "<p class=\"text-red-700 mt-2\">Type: " <> safe_html_escape(section_type_str) <> "</p>"
        html = html <> "<p class=\"text-red-700\">Title: " <> safe_html_escape(section_title) <> "</p>"
        html = html <> "<p class=\"text-red-700\">Error caught and logged</p>"
        html = html <> "</div>"
        html
    end

    result
  end

  def render_section_content(section, assigns) do
    customization = Map.get(assigns, :customization, %{})
    render_section_content_static(section, customization)
  end

  # ============================================================================
  # COLOR SCHEME MANAGEMENT - Enhanced with User Preferences
  # ============================================================================

  defp get_user_color_scheme_safe(customization) when is_map(customization) do
    base_scheme = Map.get(customization, "color_scheme", "professional")
    primary_color = Map.get(customization, "primary_color", "#3B82F6")
    secondary_color = Map.get(customization, "secondary_color", "#10B981")
    accent_color = Map.get(customization, "accent_color", "#F59E0B")

    %{
      "base" => base_scheme,
      "primary" => primary_color,
      "secondary" => secondary_color,
      "accent" => accent_color,
      "colors" => generate_color_palette(primary_color, secondary_color, accent_color)
    }
  end
  defp get_user_color_scheme_safe(_), do: default_color_scheme()

  defp default_color_scheme do
    %{
      "base" => "professional",
      "primary" => "#3B82F6",
      "secondary" => "#10B981",
      "accent" => "#F59E0B",
      "colors" => %{
        "blue" => "#3B82F6",
        "green" => "#10B981",
        "yellow" => "#F59E0B",
        "purple" => "#8B5CF6",
        "pink" => "#EC4899",
        "indigo" => "#6366F1"
      }
    }
  end

  defp generate_color_palette(primary, secondary, accent) do
    %{
      "blue" => primary,
      "green" => secondary,
      "yellow" => accent,
      "purple" => "#8B5CF6",
      "pink" => "#EC4899",
      "indigo" => "#6366F1",
      "teal" => "#14B8A6",
      "orange" => "#F97316",
      "lime" => "#84CC16",
      "cyan" => "#06B6D4"
    }
  end

  # SAFE LIST EXTRACTOR - NO Enum.map!
  defp safe_list_extract([], acc), do: Enum.reverse(acc)
  defp safe_list_extract([head | tail], acc) do
    safe_head = safe_extract(head)
    safe_list_extract(tail, [safe_head | acc])
  end

# ============================================================================
  # SKILLS SECTION - Enhanced with Color-Coded Proficiency Indicators
  # ============================================================================

  defp render_skills_content_safe(content, customization) do
    skills = Map.get(content, "items", Map.get(content, "skills", []))
    categories = Map.get(content, "categories", %{})
    display_style = Map.get(content, "display_style", "categorized")
    color_scheme = get_user_color_scheme_safe(customization)

    cond do
      is_list(skills) and length(skills) > 0 ->
        render_skills_items_safe(skills, display_style, color_scheme)

      is_map(categories) and map_size(categories) > 0 ->
        render_skills_categories_safe(categories, display_style, color_scheme)

      true ->
        render_empty_state_safe("No skills information available")
    end
  end

  defp render_skills_items_safe(skills, display_style, color_scheme) do
    case display_style do
      "categorized" ->
        # Safe grouping - NO Enum.group_by!
        grouped_skills = group_skills_by_category_safe(skills, %{})
        render_skills_grouped_safe(grouped_skills, color_scheme)

      "proficiency_bars" ->
        render_skills_with_proficiency_safe(skills, color_scheme)

      _ ->
        render_skills_flat_grid_safe(skills, color_scheme)
    end
  end

  # SAFE SKILLS GROUPING - NO Enum.group_by!
  defp group_skills_by_category_safe([], acc), do: acc
  defp group_skills_by_category_safe([skill | remaining], acc) do
    category = safe_map_get(skill, "category", "Other")
    existing_skills = Map.get(acc, category, [])
    updated_acc = Map.put(acc, category, [skill | existing_skills])
    group_skills_by_category_safe(remaining, updated_acc)
  end

  defp render_skills_categories_safe(categories, display_style, color_scheme) do
    category_html = build_categories_html_safe(Map.to_list(categories), color_scheme, "")

    html = "<div class=\"skills-section space-y-6\">"
    html = html <> category_html
    html = html <> "</div>"
    html
  end

  # SAFE CATEGORIES BUILDER - NO Enum.map or Enum.join!
  defp build_categories_html_safe([], _color_scheme, acc), do: acc
  defp build_categories_html_safe([{category_name, category_skills} | remaining], color_scheme, acc) do
    section_html = render_skills_category_section_safe(category_name, category_skills, color_scheme)
    new_acc = acc <> section_html
    build_categories_html_safe(remaining, color_scheme, new_acc)
  end

  defp render_skills_flat_grid_safe(skills, color_scheme) do
    skills_html = build_simple_skills_tags_safe(skills, color_scheme, "")

    html = "<div class=\"skills-flat-grid\">"
    html = html <> "<div class=\"flex flex-wrap gap-2\">"
    html = html <> skills_html
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  # SAFE SIMPLE SKILLS BUILDER - NO Enum.map or Enum.join!
  defp build_simple_skills_tags_safe([], _color_scheme, acc), do: acc
  defp build_simple_skills_tags_safe([skill | remaining], color_scheme, acc) do
    tag_html = render_simple_skill_tag_safe(skill, color_scheme)
    new_acc = acc <> tag_html
    build_simple_skills_tags_safe(remaining, color_scheme, new_acc)
  end

  defp render_simple_skill_tag_safe(skill, color_scheme) do
    skill_name = case skill do
      skill_map when is_map(skill_map) -> safe_map_get(skill_map, "skill_name", "Skill")
      skill_str -> safe_extract(skill_str)
    end

    # Get proficiency level for color coding
    proficiency = case skill do
      skill_map when is_map(skill_map) -> safe_map_get(skill_map, "proficiency", "Intermediate")
      _ -> "Intermediate"
    end

    # Get color from user's color scheme for variety
    {tag_color, _intensity} = get_skill_color_from_proficiency(proficiency, color_scheme, skill_name)

    # Clean minimalist design - no borders
    html = "<div class=\"bg-gray-50 rounded-lg p-3 hover:bg-gray-100 transition-colors\">"
    html = html <> "<div class=\"flex items-center justify-between\">"
    html = html <> "<span class=\"text-sm font-medium text-gray-900\">" <> safe_html_escape(skill_name) <> "</span>"
    html = html <> "<span class=\"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium " <> tag_color <> "\">"
    html = html <> safe_html_escape(proficiency)
    html = html <> "</span>"
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_skills_grouped_safe(grouped_skills, color_scheme) do
    category_html = build_grouped_categories_html_safe(Map.to_list(grouped_skills), color_scheme, "")

    html = "<div class=\"skills-section space-y-6\">"
    html = html <> category_html
    html = html <> "</div>"
    html
  end

  # SAFE GROUPED CATEGORIES BUILDER - NO Enum.map or Enum.join!
  defp build_grouped_categories_html_safe([], _color_scheme, acc), do: acc
  defp build_grouped_categories_html_safe([{category_name, category_skills} | remaining], color_scheme, acc) do
    section_html = render_skills_category_section_safe(category_name, category_skills, color_scheme)
    new_acc = acc <> section_html
    build_grouped_categories_html_safe(remaining, color_scheme, new_acc)
  end

  defp render_skills_category_section_safe(category_name, skills, color_scheme) do
    safe_category_name = safe_extract(category_name)
    skills_html = build_skill_cards_safe(skills, color_scheme, "")

    html = "<div class=\"skill-category mb-4\">"
    html = html <> "<h4 class=\"text-sm font-medium text-gray-700 mb-3\">" <> safe_html_escape(safe_category_name) <> "</h4>"
    html = html <> "<div class=\"grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3\">"
    html = html <> skills_html
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  # SAFE SKILL CARDS BUILDER - NO Enum.map or Enum.join!
  defp build_skill_cards_safe([], _color_scheme, acc), do: acc
  defp build_skill_cards_safe([skill | remaining], color_scheme, acc) do
    card_html = render_single_skill_card_safe(skill, color_scheme)
    new_acc = acc <> card_html
    build_skill_cards_safe(remaining, color_scheme, new_acc)
  end

  defp render_single_skill_card_safe(skill, color_scheme) when is_map(skill) do
    skill_name = safe_map_get(skill, "skill_name", "Skill")
    proficiency = safe_map_get(skill, "proficiency", "Intermediate")
    years = Map.get(skill, "years_experience", 0)

    # Safe years handling
    safe_years = case years do
      {:safe, content} when is_binary(content) ->
        case Integer.parse(content) do
          {num, _} -> num
          :error -> 0
        end
      num when is_integer(num) -> num
      _ -> 0
    end

    # Get enhanced proficiency colors based on skill name and user color scheme
    {tag_color, intensity} = get_skill_color_from_proficiency(proficiency, color_scheme, skill_name)
    years_badge = if safe_years > 0, do: render_years_badge_safe(safe_years), else: ""

    # Enhanced skill card with visual proficiency indicator
    html = "<div class=\"bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"
    html = html <> "<div class=\"flex items-center justify-between mb-3\">"
    html = html <> "<h5 class=\"font-medium text-gray-900 text-sm\">" <> safe_html_escape(skill_name) <> "</h5>"
    html = html <> years_badge
    html = html <> "</div>"

    # Visual proficiency indicator with color progression
    html = html <> "<div class=\"skill-proficiency\">"
    html = html <> "<div class=\"flex items-center justify-between mb-2\">"
    html = html <> "<span class=\"text-xs text-gray-600\">" <> safe_html_escape(proficiency) <> "</span>"
    html = html <> "<span class=\"text-xs text-gray-500\">" <> Integer.to_string(intensity) <> "%</span>"
    html = html <> "</div>"

    # Visual progress bar with user's color scheme
    {progress_color, _} = get_progress_bar_color(proficiency, color_scheme)
    html = html <> "<div class=\"proficiency-visual h-2 bg-gray-200 rounded-full overflow-hidden\">"
    html = html <> "<div class=\"proficiency-fill h-full " <> progress_color <> " rounded-full transition-all duration-500\""
    html = html <> " style=\"width: " <> Integer.to_string(intensity) <> "%\"></div>"
    html = html <> "</div>"
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_skills_with_proficiency_safe(skills, color_scheme) do
    skills_html = build_proficiency_skill_cards_safe(skills, color_scheme, "")

    html = "<div class=\"skills-proficiency-grid grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4\">"
    html = html <> skills_html
    html = html <> "</div>"
    html
  end

  # SAFE PROFICIENCY CARDS BUILDER - NO Enum.map or Enum.join!
  defp build_proficiency_skill_cards_safe([], _color_scheme, acc), do: acc
  defp build_proficiency_skill_cards_safe([skill | remaining], color_scheme, acc) do
    card_html = render_single_skill_card_safe(skill, color_scheme)
    new_acc = acc <> card_html
    build_proficiency_skill_cards_safe(remaining, color_scheme, new_acc)
  end

  defp render_years_badge_safe(years) do
    html = "<span class=\"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-200 text-gray-600\">"
    html = html <> Integer.to_string(years) <> "y"
    html = html <> "</span>"
    html
  end

  # Enhanced color system based on proficiency level and user color scheme
  defp get_skill_color_from_proficiency(proficiency, color_scheme, skill_name) do
    proficiency_str = safe_extract(proficiency) |> String.downcase()

    # Get user's color palette and add variety colors
    user_colors = Map.get(color_scheme, "colors", %{})
    primary = Map.get(color_scheme, "primary", "#3B82F6")
    secondary = Map.get(color_scheme, "secondary", "#10B981")
    accent = Map.get(color_scheme, "accent", "#F59E0B")

    # Extended color palette for variety
    color_palette = [
      primary,
      secondary,
      accent,
      "#8B5CF6", # purple
      "#EC4899", # pink
      "#6366F1", # indigo
      "#14B8A6", # teal
      "#F97316", # orange
      "#84CC16", # lime
      "#06B6D4"  # cyan
    ]

    # Select color based on skill name for consistency
    color_index = :erlang.phash2(skill_name, length(color_palette))
    selected_color = Enum.at(color_palette, color_index)

    # Convert hex to color name for Tailwind classes
    base_color = case selected_color do
      ^primary -> "blue"
      ^secondary -> "green"
      ^accent -> "yellow"
      "#8B5CF6" -> "purple"
      "#EC4899" -> "pink"
      "#6366F1" -> "indigo"
      "#14B8A6" -> "teal"
      "#F97316" -> "orange"
      "#84CC16" -> "lime"
      "#06B6D4" -> "cyan"
      _ -> "blue"
    end

    # Proficiency determines shade intensity and percentage
    case proficiency_str do
      level when level in ["expert", "advanced"] ->
        {"bg-" <> base_color <> "-600 text-white", 95}
      level when level in ["intermediate", "proficient"] ->
        {"bg-" <> base_color <> "-500 text-white", 75}
      level when level in ["beginner", "basic", "learning"] ->
        {"bg-" <> base_color <> "-300 text-" <> base_color <> "-800", 45}
      _ ->
        {"bg-" <> base_color <> "-400 text-white", 60}
    end
  end

  # Get progress bar color for visual indicators
  defp get_progress_bar_color(proficiency, color_scheme) do
    proficiency_str = safe_extract(proficiency) |> String.downcase()
    primary = Map.get(color_scheme, "primary", "#3B82F6")

    # Use primary color with different intensities
    case proficiency_str do
      level when level in ["expert", "advanced"] ->
        {"bg-green-500", 95}
      level when level in ["intermediate", "proficient"] ->
        {"bg-blue-500", 75}
      level when level in ["beginner", "basic", "learning"] ->
        {"bg-yellow-500", 45}
      _ ->
        {"bg-gray-400", 60}
    end
  end

  # ============================================================================
  # EXPERIENCE SECTION - Enhanced with Professional Timeline
  # ============================================================================

  defp render_experience_content_safe(content, customization) do
    experiences = Map.get(content, "items", [])
    display_style = Map.get(content, "display_style", "timeline")

    if is_list(experiences) and length(experiences) > 0 do
      render_experience_timeline_safe(experiences, customization)
    else
      render_empty_state_safe("No work experience available")
    end
  end

  defp render_experience_timeline_safe(experiences, customization) do
    # Build timeline HTML using pure string concatenation - NO Enum.map or Enum.join!
    experiences_html = build_experiences_html_safe(experiences, customization, 0, "")

    # Clean timeline container - no borders
    html = "<div class=\"experience-timeline space-y-4\">"
    html = html <> experiences_html
    html = html <> "</div>"
    html
  end

  # SAFE EXPERIENCE HTML BUILDER - NO Enum.map or Enum.join!
  defp build_experiences_html_safe([], _customization, _index, acc), do: acc
  defp build_experiences_html_safe([experience | remaining], customization, index, acc) do
    item_html = try do
      render_single_experience_item_safe(experience, index, customization)
    rescue
      error ->
        IO.puts("❌ EXPERIENCE: Error rendering item " <> Integer.to_string(index) <> ": #{inspect(error)}")
        "<div class=\"p-4 bg-yellow-50 rounded-lg\"><p class=\"text-yellow-800 text-sm\">Experience item rendering error</p></div>"
    end

    new_acc = acc <> item_html
    build_experiences_html_safe(remaining, customization, index + 1, new_acc)
  end

  defp render_single_experience_item_safe(experience, index, customization) when is_map(experience) do
    # Safe field extraction
    title = safe_map_get(experience, "title", "Position")
    company = safe_map_get(experience, "company", "Company")
    location = safe_map_get(experience, "location", "")
    employment_type = safe_map_get(experience, "employment_type", "")
    start_date = safe_map_get(experience, "start_date", "")
    end_date = safe_map_get(experience, "end_date", "")
    is_current = Map.get(experience, "is_current", false)
    description = safe_map_get(experience, "description", "")

    # Safe array handling
    achievements = case Map.get(experience, "achievements", []) do
      list when is_list(list) -> safe_list_extract(list, [])
      _ -> []
    end

    skills_used = case Map.get(experience, "skills_used", []) do
      list when is_list(list) -> safe_list_extract(list, [])
      _ -> []
    end

    date_range = format_date_range_safe(start_date, end_date, is_current)
    employment_badge = if employment_type != "", do: render_employment_badge_safe(employment_type), else: ""
    achievements_display = render_achievements_safe(achievements)
    skills_display = render_skills_used_safe(skills_used)

    # Build HTML with pure string concatenation - NO string interpolation!
    try do
      # Clean card styling - no borders, consistent design
      html = "<div class=\"experience-item bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"

      html = html <> "<div class=\"experience-header mb-3\">"
      html = html <> "<div class=\"flex items-start justify-between\">"
      html = html <> "<div class=\"flex-1\">"
      html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-1\">" <> safe_html_escape(title) <> "</h4>"
      html = html <> "<div class=\"flex items-center text-gray-600 mb-2\">"
      html = html <> "<span class=\"font-medium\">" <> safe_html_escape(company) <> "</span>"

      if location != "" do
        html = html <> "<span class=\"mx-2 text-gray-400\">•</span><span class=\"text-sm\">" <> safe_html_escape(location) <> "</span>"
      end

      html = html <> "</div>"
      html = html <> "</div>"
      html = html <> "<div class=\"text-right flex-shrink-0\">"
      html = html <> employment_badge
      html = html <> "<div class=\"text-sm text-gray-500 mt-1\">" <> date_range <> "</div>"
      html = html <> "</div>"
      html = html <> "</div>"

      if description != "" do
        html = html <> "<p class=\"text-gray-700 leading-relaxed text-sm mb-3\">" <> safe_html_escape(description) <> "</p>"
      end

      html = html <> "</div>"
      html = html <> achievements_display
      html = html <> skills_display
      html = html <> "</div>"
      html
    rescue
      error ->
        IO.puts("❌ EXPERIENCE: Error building final HTML: #{inspect(error)}")
        "<div class=\"p-4 bg-yellow-50 rounded-lg\"><p class=\"text-yellow-800 text-sm\">Experience item rendering error</p></div>"
    end
  end

  defp render_employment_badge_safe(employment_type) do
    # Enhanced employment badge with better styling
    badge_color = case String.downcase(employment_type) do
      "full-time" -> "bg-green-100 text-green-700"
      "part-time" -> "bg-blue-100 text-blue-700"
      "contract" -> "bg-purple-100 text-purple-700"
      "freelance" -> "bg-yellow-100 text-yellow-700"
      "internship" -> "bg-indigo-100 text-indigo-700"
      _ -> "bg-gray-100 text-gray-700"
    end

    html = "<span class=\"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium " <> badge_color <> "\">"
    html = html <> safe_html_escape(employment_type)
    html = html <> "</span>"
    html
  end

  defp render_achievements_safe(achievements) when is_list(achievements) and length(achievements) > 0 do
    # Calculate if we should use expandable view
    total_length = calculate_total_length_safe(achievements, 0)
    avg_length = if length(achievements) > 0, do: total_length / length(achievements), else: 0

    if avg_length > 100 do
      render_achievements_expandable_safe(achievements)
    else
      render_achievements_bullets_safe(achievements)
    end
  end
  defp render_achievements_safe(_), do: ""

  # SAFE LENGTH CALCULATOR - NO Enum.map or Enum.sum!
  defp calculate_total_length_safe([], acc), do: acc
  defp calculate_total_length_safe([achievement | remaining], acc) do
    clean_achievement = safe_extract(achievement)
    new_acc = acc + String.length(clean_achievement)
    calculate_total_length_safe(remaining, new_acc)
  end

  defp render_achievements_bullets_safe(achievements) do
    bullets_html = build_achievements_bullets_safe(achievements, "")

    html = "<div class=\"achievements mb-3\">"
    html = html <> "<h5 class=\"font-medium text-gray-900 mb-2 text-sm\">Key Achievements</h5>"
    html = html <> "<ul class=\"space-y-1\">"
    html = html <> bullets_html
    html = html <> "</ul>"
    html = html <> "</div>"
    html
  end

  # SAFE BULLETS BUILDER - NO Enum.map or Enum.join!
  defp build_achievements_bullets_safe([], acc), do: acc
  defp build_achievements_bullets_safe([achievement | remaining], acc) do
    clean_achievement = safe_extract(achievement)

    bullet_html = "<li class=\"flex items-start\">"
    bullet_html = bullet_html <> "<span class=\"flex-shrink-0 w-1 h-1 bg-blue-500 rounded-full mt-2 mr-2\"></span>"
    bullet_html = bullet_html <> "<span class=\"text-gray-600 text-sm leading-snug\">" <> safe_html_escape(clean_achievement) <> "</span>"
    bullet_html = bullet_html <> "</li>"

    new_acc = acc <> bullet_html
    build_achievements_bullets_safe(remaining, new_acc)
  end

  defp render_achievements_expandable_safe(achievements) do
    first_achievement = case achievements do
      [first | _] -> safe_extract(first)
      [] -> ""
    end

    preview = if String.length(first_achievement) > 120 do
      String.slice(first_achievement, 0, 120)
    else
      first_achievement
    end

    remaining_count = length(achievements) - 1

    html = "<div class=\"achievements mb-4\">"
    html = html <> "<h5 class=\"font-medium text-gray-900 mb-2\">Key Achievements</h5>"
    html = html <> "<div class=\"achievement-preview p-3 bg-gray-100 rounded-lg\">"
    html = html <> "<p class=\"text-gray-700\">" <> safe_html_escape(preview)

    if String.length(first_achievement) > 120 do
      html = html <> "..."
    end

    html = html <> "</p>"

    if remaining_count > 0 do
      html = html <> "<button type=\"button\" class=\"mt-2 text-sm text-blue-600 hover:text-blue-700 font-medium\">"
      html = html <> "View " <> Integer.to_string(remaining_count) <> " more achievement"
      if remaining_count > 1 do
        html = html <> "s"
      end
      html = html <> "</button>"
    end

    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_skills_used_safe(skills) when is_list(skills) and length(skills) > 0 do
    skills_html = build_skills_tags_safe(skills, "")

    html = "<div class=\"skills-used mt-3\">"
    html = html <> "<h5 class=\"font-medium text-gray-900 mb-2 text-sm\">Technologies Used</h5>"
    html = html <> "<div class=\"flex flex-wrap gap-1\">"
    html = html <> skills_html
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end
  defp render_skills_used_safe(_), do: ""

  # SAFE SKILLS TAGS BUILDER - NO Enum.map or Enum.join!
  defp build_skills_tags_safe([], acc), do: acc
  defp build_skills_tags_safe([skill | remaining], acc) do
    clean_skill = safe_extract(skill)

    tag_html = "<span class=\"inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-50 text-blue-700\">"
    tag_html = tag_html <> safe_html_escape(clean_skill)
    tag_html = tag_html <> "</span>"

    new_acc = acc <> tag_html
    build_skills_tags_safe(remaining, new_acc)
  end

  # ============================================================================
  # PROJECTS SECTION - Enhanced with Technology Tags
  # ============================================================================

  defp render_projects_content_safe(content, _customization) do
    projects = Map.get(content, "items", [])

    if is_list(projects) and length(projects) > 0 do
      projects_html = build_project_items_safe(projects, "")

      html = "<div class=\"projects-grid space-y-4\">"
      html = html <> projects_html
      html = html <> "</div>"
      html
    else
      render_empty_state_safe("No projects available")
    end
  end

  # SAFE PROJECT ITEMS BUILDER - NO Enum.map or Enum.join!
  defp build_project_items_safe([], acc), do: acc
  defp build_project_items_safe([project | remaining], acc) do
    item_html = render_single_project_item_safe(project)
    new_acc = acc <> item_html
    build_project_items_safe(remaining, new_acc)
  end

defp render_single_project_item_safe(project) when is_map(project) do
    title = safe_map_get(project, "title", "Project")
    description = safe_map_get(project, "description", "")
    methodology = safe_map_get(project, "methodology", "")

    # Safe technologies array handling
    technologies = case Map.get(project, "technologies", []) do
      list when is_list(list) -> safe_list_extract(list, [])
      _ -> []
    end

    url = safe_map_get(project, "url", "")
    github_url = safe_map_get(project, "github_url", "")
    demo_url = safe_map_get(project, "demo_url", "")
    start_date = safe_map_get(project, "start_date", "")
    end_date = safe_map_get(project, "end_date", "")
    status = safe_map_get(project, "status", "")
    client = safe_map_get(project, "client", "")
    role = safe_map_get(project, "role", "")

    # Enhanced project status badge
    status_badge = if status != "" do
      status_lower = String.downcase(status)
      status_color = cond do
        status_lower in ["completed", "live", "deployed"] -> "bg-green-50 text-green-700"
        status_lower in ["in-progress", "active", "development"] -> "bg-blue-50 text-blue-700"
        status_lower in ["on-hold", "paused"] -> "bg-yellow-50 text-yellow-700"
        status_lower in ["cancelled", "archived"] -> "bg-red-50 text-red-700"
        true -> "bg-gray-50 text-gray-700"
      end

      badge_html = "<span class=\"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium " <> status_color <> "\">"
      badge_html = badge_html <> safe_html_escape(status)
      badge_html = badge_html <> "</span>"
      badge_html
    else
      ""
    end

    # Methodology badge
    methodology_badge = if methodology != "" do
      methodology_lower = String.downcase(methodology)
      method_color = cond do
        methodology_lower == "agile" -> "bg-green-50 text-green-700"
        methodology_lower == "waterfall" -> "bg-blue-50 text-blue-700"
        methodology_lower == "scrum" -> "bg-purple-50 text-purple-700"
        methodology_lower == "kanban" -> "bg-orange-50 text-orange-700"
        methodology_lower == "lean" -> "bg-teal-50 text-teal-700"
        true -> "bg-gray-50 text-gray-700"
      end

      badge_html = "<span class=\"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium " <> method_color <> "\">"
      badge_html = badge_html <> safe_html_escape(methodology)
      badge_html = badge_html <> "</span>"
      badge_html
    else
      ""
    end

    # Technology tags with variety colors
    tech_tags = if length(technologies) > 0 do
      tech_html = build_tech_tags_safe(technologies, "")

      html = "<div class=\"technologies mt-3\">"
      html = html <> "<h6 class=\"text-xs font-medium text-gray-500 mb-1\">Technologies</h6>"
      html = html <> "<div class=\"flex flex-wrap gap-1\">"
      html = html <> tech_html
      html = html <> "</div>"
      html = html <> "</div>"
      html
    else
      ""
    end

    # Project links with enhanced variety
    links = []
    links = if safe_not_empty?(url), do: [render_project_link_safe(url, "View Project") | links], else: links
    links = if safe_not_empty?(demo_url), do: [render_project_link_safe(demo_url, "Live Demo") | links], else: links
    links = if safe_not_empty?(github_url), do: [render_project_link_safe(github_url, "View Code") | links], else: links

    links_html = if length(links) > 0 do
      links_content = build_project_links_html_safe(links, "")

      html = "<div class=\"project-links mt-3 flex gap-2\">"
      html = html <> links_content
      html = html <> "</div>"
      html
    else
      ""
    end

    # Date range display
    date_range = if safe_not_empty?(start_date) do
      if safe_not_empty?(end_date) do
        format_date_display_safe(start_date) <> " - " <> format_date_display_safe(end_date)
      else
        format_date_display_safe(start_date) <> " - Present"
      end
    else
      ""
    end

    # Client and role information
    project_meta = []
    project_meta = if safe_not_empty?(client), do: ["Client: " <> safe_html_escape(client) | project_meta], else: project_meta
    project_meta = if safe_not_empty?(role), do: ["Role: " <> safe_html_escape(role) | project_meta], else: project_meta

    project_meta_html = if length(project_meta) > 0 do
      meta_content = build_project_meta_html_safe(project_meta, "")

      html = "<div class=\"project-meta mt-2 text-xs text-gray-500\">"
      html = html <> meta_content
      html = html <> "</div>"
      html
    else
      ""
    end

    # Build complete project card
    html = "<div class=\"project-item bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"

    # Project header with title and badges
    html = html <> "<div class=\"project-header mb-3\">"
    html = html <> "<div class=\"flex items-start justify-between mb-2\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 flex-1\">" <> safe_html_escape(title) <> "</h4>"
    html = html <> "<div class=\"flex gap-1 ml-2\">"
    html = html <> status_badge
    html = html <> methodology_badge
    html = html <> "</div>"
    html = html <> "</div>"

    # Date range if available
    if date_range != "" do
      html = html <> "<div class=\"text-xs text-gray-500 mb-2\">" <> date_range <> "</div>"
    end

    html = html <> "</div>"

    # Project description
    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700 leading-relaxed text-sm mb-3\">" <> safe_html_escape(description) <> "</p>"
    end

    # Project metadata (client, role)
    html = html <> project_meta_html

    # Technology tags
    html = html <> tech_tags

    # Project links
    html = html <> links_html

    html = html <> "</div>"
    html
  end

  # Helper function to build project meta HTML safely
  defp build_project_meta_html_safe([], acc), do: acc
  defp build_project_meta_html_safe([meta | remaining], acc) do
    meta_html = "<span class=\"inline-block mr-3\">" <> meta <> "</span>"
    new_acc = acc <> meta_html
    build_project_meta_html_safe(remaining, new_acc)
  end

  # SAFE TECH TAGS BUILDER - Enhanced with variety
  defp build_tech_tags_safe([], acc), do: acc
  defp build_tech_tags_safe([tech | remaining], acc) do
    # Cycle through colors for variety
    color_options = ["blue", "green", "purple", "indigo", "pink", "yellow"]
    color_index = :erlang.phash2(tech, length(color_options))
    selected_color = Enum.at(color_options, color_index)

    tag_html = "<span class=\"inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-" <> selected_color <> "-50 text-" <> selected_color <> "-700\">"
    tag_html = tag_html <> safe_html_escape(tech)
    tag_html = tag_html <> "</span>"

    new_acc = acc <> tag_html
    build_tech_tags_safe(remaining, new_acc)
  end

  # SAFE PROJECT LINKS HTML BUILDER - NO Enum.join!
  defp build_project_links_html_safe([], acc), do: acc
  defp build_project_links_html_safe([link | remaining], acc) do
    new_acc = acc <> link
    build_project_links_html_safe(remaining, new_acc)
  end

  defp render_project_link_safe(url, label) do
    clean_url = safe_extract(url)

    link_color = case label do
      "View Project" -> "bg-blue-600 hover:bg-blue-700 text-white"
      "View Code" -> "bg-gray-600 hover:bg-gray-700 text-white"
      _ -> "bg-green-600 hover:bg-green-700 text-white"
    end

    html = "<a href=\"" <> safe_html_escape(clean_url) <> "\" target=\"_blank\" rel=\"noopener noreferrer\""
    html = html <> " class=\"inline-flex items-center px-3 py-1.5 rounded text-sm font-medium " <> link_color <> " transition-colors\">"
    html = html <> label
    html = html <> "</a>"
    html
  end

  # ============================================================================
  # EDUCATION SECTION - Enhanced with Degree Recognition
  # ============================================================================

  defp render_education_content_safe(content, _customization) do
    education_items = Map.get(content, "items", [])

    if is_list(education_items) and length(education_items) > 0 do
      education_html = build_education_items_safe(education_items, "")

      html = "<div class=\"education-timeline space-y-4\">"
      html = html <> education_html
      html = html <> "</div>"
      html
    else
      render_empty_state_safe("No education information available")
    end
  end

  # SAFE EDUCATION ITEMS BUILDER - NO Enum.map or Enum.join!
  defp build_education_items_safe([], acc), do: acc
  defp build_education_items_safe([education | remaining], acc) do
    item_html = render_single_education_item_safe(education)
    new_acc = acc <> item_html
    build_education_items_safe(remaining, new_acc)
  end

  defp render_single_education_item_safe(education) when is_map(education) do
    degree = safe_map_get(education, "degree", "Degree")
    institution = safe_map_get(education, "institution", "Institution")
    field_of_study = safe_map_get(education, "field_of_study", "")
    graduation_date = safe_map_get(education, "graduation_date", "")
    gpa = safe_map_get(education, "gpa", "")
    honors = Map.get(education, "honors", [])

    # Enhanced degree display with level badges
    degree_lower = String.downcase(degree)
    degree_badge = cond do
      String.contains?(degree_lower, "phd") or String.contains?(degree_lower, "doctorate") ->
        "bg-purple-50 text-purple-700"
      String.contains?(degree_lower, "master") or String.contains?(degree_lower, "msc") or String.contains?(degree_lower, "mba") ->
        "bg-blue-50 text-blue-700"
      String.contains?(degree_lower, "bachelor") or String.contains?(degree_lower, "bsc") or String.contains?(degree_lower, "ba") ->
        "bg-green-50 text-green-700"
      true ->
        "bg-gray-50 text-gray-700"
    end

    html = "<div class=\"education-item bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"
    html = html <> "<div class=\"flex items-start justify-between mb-3\">"
    html = html <> "<div class=\"flex-1\">"
    html = html <> "<div class=\"flex items-center mb-2\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mr-2\">" <> safe_html_escape(degree) <> "</h4>"
    html = html <> "<span class=\"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium " <> degree_badge <> "\">Degree</span>"
    html = html <> "</div>"
    html = html <> "<p class=\"text-md text-gray-700 font-medium\">" <> safe_html_escape(institution) <> "</p>"

    if safe_not_empty?(field_of_study) do
      html = html <> "<p class=\"text-gray-600 text-sm\">" <> safe_html_escape(field_of_study) <> "</p>"
    end

    html = html <> "</div>"
    html = html <> "<div class=\"text-right flex-shrink-0\">"

    if safe_not_empty?(graduation_date) do
      html = html <> "<div class=\"text-sm text-gray-500\">" <> safe_html_escape(graduation_date) <> "</div>"
    end

    if safe_not_empty?(gpa) do
      html = html <> "<div class=\"text-sm text-gray-500 mt-1\">GPA: " <> safe_html_escape(gpa) <> "</div>"
    end

    html = html <> "</div>"
    html = html <> "</div>"

    if is_list(honors) and length(honors) > 0 do
      html = html <> render_honors_list_safe(honors)
    end

    html = html <> "</div>"
    html
  end

  defp render_honors_list_safe(honors) do
    honors_html = build_honors_tags_safe(honors, "")

    html = "<div class=\"honors mt-3\">"
    html = html <> "<h5 class=\"font-medium text-gray-900 mb-2 text-sm\">Honors & Awards</h5>"
    html = html <> "<div class=\"flex flex-wrap gap-1\">"
    html = html <> honors_html
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  # SAFE HONORS TAGS BUILDER - Enhanced with variety
  defp build_honors_tags_safe([], acc), do: acc
  defp build_honors_tags_safe([honor | remaining], acc) do
    clean_honor = safe_extract(honor)
    clean_honor_lower = String.downcase(clean_honor)

    # Color based on honor type
    honor_color = cond do
      String.contains?(clean_honor_lower, "magna cum laude") -> "bg-yellow-50 text-yellow-700"
      String.contains?(clean_honor_lower, "cum laude") -> "bg-amber-50 text-amber-700"
      String.contains?(clean_honor_lower, "dean") -> "bg-purple-50 text-purple-700"
      String.contains?(clean_honor_lower, "scholarship") -> "bg-blue-50 text-blue-700"
      true -> "bg-green-50 text-green-700"
    end

    tag_html = "<span class=\"inline-flex items-center px-2 py-1 rounded text-xs font-medium " <> honor_color <> "\">"
    tag_html = tag_html <> safe_html_escape(clean_honor)
    tag_html = tag_html <> "</span>"

    new_acc = acc <> tag_html
    build_honors_tags_safe(remaining, new_acc)
  end

  # ============================================================================
  # CONTACT SECTION - Enhanced with Professional Layout
  # ============================================================================

  defp render_contact_content_safe(content, _customization) do
    email = safe_map_get(content, "email", "")
    phone = safe_map_get(content, "phone", "")
    location = safe_map_get(content, "location", "")
    website = safe_map_get(content, "website", "")
    social_links = Map.get(content, "social_links", %{})

    # Build contact items using safe accumulation - NO Enum.filter or Enum.map!
    contact_items = []
    contact_items = if safe_not_empty?(email), do: [render_contact_item_safe("email", email, "Email") | contact_items], else: contact_items
    contact_items = if safe_not_empty?(phone), do: [render_contact_item_safe("phone", phone, "Phone") | contact_items], else: contact_items
    contact_items = if safe_not_empty?(location), do: [render_contact_item_safe("location", location, "Location") | contact_items], else: contact_items
    contact_items = if safe_not_empty?(website), do: [render_contact_item_safe("website", website, "Website") | contact_items], else: contact_items

    # Safe social links handling
    social_items = build_social_items_safe(Map.to_list(social_links), [])

    contact_items_html = build_contact_items_html_safe(contact_items, "")
    social_items_html = build_social_items_html_safe(social_items, "")

    html = "<div class=\"contact-content\">"

    if length(contact_items) > 0 do
      html = html <> "<div class=\"contact-info mb-4\">"
      html = html <> "<div class=\"grid grid-cols-1 sm:grid-cols-2 gap-3\">"
      html = html <> contact_items_html
      html = html <> "</div>"
      html = html <> "</div>"
    end

    if length(social_items) > 0 do
      html = html <> "<div class=\"social-links\">"
      html = html <> "<h4 class=\"font-medium text-gray-900 mb-3 text-sm\">Connect</h4>"
      html = html <> "<div class=\"grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2\">"
      html = html <> social_items_html
      html = html <> "</div>"
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  # SAFE SOCIAL ITEMS BUILDER - NO Enum.filter or Enum.map!
  defp build_social_items_safe([], acc), do: Enum.reverse(acc)
  defp build_social_items_safe([{platform, url} | remaining], acc) do
    safe_url = safe_extract(url)
    if safe_not_empty?(safe_url) do
      social_item = render_social_item_safe(platform, url)
      build_social_items_safe(remaining, [social_item | acc])
    else
      build_social_items_safe(remaining, acc)
    end
  end

  # SAFE CONTACT ITEMS HTML BUILDER - NO Enum.join!
  defp build_contact_items_html_safe([], acc), do: acc
  defp build_contact_items_html_safe([item | remaining], acc) do
    new_acc = acc <> item
    build_contact_items_html_safe(remaining, new_acc)
  end

  # SAFE SOCIAL ITEMS HTML BUILDER - NO Enum.join!
  defp build_social_items_html_safe([], acc), do: acc
  defp build_social_items_html_safe([item | remaining], acc) do
    new_acc = acc <> item
    build_social_items_html_safe(remaining, new_acc)
  end

  defp render_contact_item_safe(type, value, label) do
    clean_value = safe_extract(value)
    icon = get_contact_icon(type)

    html = "<div class=\"bg-gray-50 rounded-lg p-3 hover:bg-gray-100 transition-colors\">"
    html = html <> "<div class=\"flex items-center gap-2 mb-1\">"
    html = html <> icon
    html = html <> "<span class=\"text-xs font-medium text-gray-500\">" <> label <> "</span>"
    html = html <> "</div>"
    html = html <> "<div class=\"text-sm text-gray-900\">" <> safe_html_escape(clean_value) <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_social_item_safe(platform, url) do
    clean_url = safe_extract(url)
    {icon, platform_name, _color_class} = get_platform_details(platform)

    html = "<a href=\"" <> safe_html_escape(clean_url) <> "\" target=\"_blank\" rel=\"noopener noreferrer\""
    html = html <> " class=\"bg-gray-50 rounded-lg p-3 hover:bg-gray-100 transition-colors inline-flex items-center gap-2\">"
    html = html <> icon
    html = html <> "<span class=\"text-xs font-medium text-gray-700\">" <> platform_name <> "</span>"
    html = html <> "</a>"
    html
  end

  defp get_contact_icon(type) do
    case type do
      "email" -> render_email_icon()
      "phone" -> render_phone_icon()
      "location" -> render_location_icon()
      "website" -> render_website_icon()
      _ -> render_link_icon()
    end
  end

  defp get_platform_details(platform) do
    case String.downcase(safe_extract(platform)) do
      "linkedin" -> {render_linkedin_icon(), "LinkedIn", "hover:bg-blue-50"}
      "github" -> {render_github_icon(), "GitHub", "hover:bg-gray-50"}
      "twitter" -> {render_twitter_icon(), "Twitter", "hover:bg-blue-50"}
      "website" -> {render_website_icon(), "Website", "hover:bg-green-50"}
      "email" -> {render_email_icon(), "Email", "hover:bg-red-50"}
      _ -> {render_link_icon(), String.capitalize(safe_extract(platform)), "hover:bg-gray-50"}
    end
  end

  # ============================================================================
  # INTRO/ABOUT SECTION - Enhanced with Better Styling
  # ============================================================================

  defp render_intro_content_safe(content, _customization) do
    story = safe_map_get(content, "story", safe_map_get(content, "description", safe_map_get(content, "content", "")))
    highlights = Map.get(content, "highlights", [])

    highlights_display = if is_list(highlights) and length(highlights) > 0 do
      highlights_html = build_highlights_list_safe(highlights, "")

      html = "<div class=\"highlights mt-4\">"
      html = html <> "<h4 class=\"font-medium text-gray-900 mb-2 text-sm\">Highlights</h4>"
      html = html <> "<ul class=\"space-y-1\">"
      html = html <> highlights_html
      html = html <> "</ul>"
      html = html <> "</div>"
      html
    else
      ""
    end

    html = "<div class=\"intro-content\">"
    html = html <> "<div class=\"prose max-w-none\">"
    html = html <> "<p class=\"text-gray-700 leading-relaxed text-sm\">" <> safe_html_escape(story) <> "</p>"
    html = html <> "</div>"
    html = html <> highlights_display
    html = html <> "</div>"
    html
  end

  # SAFE HIGHLIGHTS BUILDER - Enhanced styling
  defp build_highlights_list_safe([], acc), do: acc
  defp build_highlights_list_safe([highlight | remaining], acc) do
    safe_highlight = safe_extract(highlight)

    item_html = "<li class=\"flex items-start\">"
    item_html = item_html <> "<span class=\"flex-shrink-0 w-1 h-1 bg-blue-500 rounded-full mt-2 mr-2\"></span>"
    item_html = item_html <> "<span class=\"text-gray-600 text-sm leading-snug\">" <> safe_html_escape(safe_highlight) <> "</span>"
    item_html = item_html <> "</li>"

    new_acc = acc <> item_html
    build_highlights_list_safe(remaining, new_acc)
  end

  # ============================================================================
  # ACHIEVEMENTS SECTION - Enhanced Implementation
  # ============================================================================

  defp render_achievements_section_safe(content, _customization) do
    achievements = Map.get(content, "items", Map.get(content, "achievements", []))

    if is_list(achievements) and length(achievements) > 0 do
      achievements_html = build_achievement_items_safe(achievements, "")

      html = "<div class=\"achievements-section space-y-3\">"
      html = html <> achievements_html
      html = html <> "</div>"
      html
    else
      render_empty_state_safe("No achievements available")
    end
  end

  # SAFE ACHIEVEMENT ITEMS BUILDER
  defp build_achievement_items_safe([], acc), do: acc
  defp build_achievement_items_safe([achievement | remaining], acc) do
    item_html = render_single_achievement_item_safe(achievement)
    new_acc = acc <> item_html
    build_achievement_items_safe(remaining, new_acc)
  end

  defp render_single_achievement_item_safe(achievement) when is_map(achievement) do
    title = safe_map_get(achievement, "title", safe_map_get(achievement, "name", "Achievement"))
    description = safe_map_get(achievement, "description", "")
    date = safe_map_get(achievement, "date", "")
    organization = safe_map_get(achievement, "organization", "")

    html = "<div class=\"bg-gray-50 rounded-lg p-3 hover:bg-gray-100 transition-colors\">"
    html = html <> "<div class=\"flex items-start justify-between mb-2\">"
    html = html <> "<h4 class=\"font-medium text-gray-900 text-sm\">" <> safe_html_escape(title) <> "</h4>"

    if safe_not_empty?(date) do
      html = html <> "<span class=\"text-xs text-gray-500\">" <> safe_html_escape(date) <> "</span>"
    end

    html = html <> "</div>"

    if safe_not_empty?(organization) do
      html = html <> "<p class=\"text-xs text-gray-600 mb-1\">" <> safe_html_escape(organization) <> "</p>"
    end

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-xs text-gray-700\">" <> safe_html_escape(description) <> "</p>"
    end

    html = html <> "</div>"
    html
  end

  defp render_single_achievement_item_safe(achievement) do
    # Handle string achievements
    clean_achievement = safe_extract(achievement)

    html = "<div class=\"bg-gray-50 rounded-lg p-3 hover:bg-gray-100 transition-colors\">"
    html = html <> "<p class=\"text-sm text-gray-900\">" <> safe_html_escape(clean_achievement) <> "</p>"
    html = html <> "</div>"
    html
  end

  # ============================================================================
  # GENERIC CONTENT - Enhanced Styling
  # ============================================================================

  defp render_generic_content_safe(content, _customization) do
    description = safe_map_get(content, "description", safe_map_get(content, "content", ""))

    if safe_not_empty?(description) do
      html = "<div class=\"generic-content\">"
      html = html <> "<p class=\"text-gray-700 leading-relaxed text-sm\">" <> safe_html_escape(description) <> "</p>"
      html = html <> "</div>"
      html
    else
      render_empty_state_safe("No content available")
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS - Safe Implementation
  # ============================================================================

  defp format_date_range_safe(start_date, end_date, is_current) do
    start_formatted = format_date_display_safe(start_date)

    cond do
      is_current -> start_formatted <> " - Present"
      safe_not_empty?(end_date) -> start_formatted <> " - " <> format_date_display_safe(end_date)
      true -> start_formatted
    end
  end

  defp format_date_display_safe(date) do
    clean_date = safe_extract(date)

    if clean_date != "" do
      case String.split(clean_date, "-") do
        [year, month | _] -> format_month_safe(month) <> "/" <> year
        _ -> clean_date
      end
    else
      ""
    end
  end

  defp format_month_safe(month_str) do
    case month_str do
      "01" -> "Jan"
      "02" -> "Feb"
      "03" -> "Mar"
      "04" -> "Apr"
      "05" -> "May"
      "06" -> "Jun"
      "07" -> "Jul"
      "08" -> "Aug"
      "09" -> "Sep"
      "10" -> "Oct"
      "11" -> "Nov"
      "12" -> "Dec"
      _ -> month_str
    end
  end

  # ============================================================================
  # EMPTY STATE - Enhanced Styling
  # ============================================================================

  defp render_empty_state_safe(message) do
    html = "<div class=\"empty-state text-center py-8\">"
    html = html <> "<div class=\"text-gray-300 mb-2\">"
    html = html <> "<svg class=\"w-8 h-8 mx-auto\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
    html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z\"/>"
    html = html <> "</svg>"
    html = html <> "</div>"
    html = html <> "<p class=\"text-gray-400 text-sm\">" <> safe_html_escape(message) <> "</p>"
    html = html <> "</div>"
    html
  end

  # ============================================================================
  # ICON RENDERING FUNCTIONS - Consistent Sizing
  # ============================================================================

  defp render_email_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
    </svg>
    """
  end

  defp render_phone_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
    </svg>
    """
  end

  defp render_location_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
    </svg>
    """
  end

  defp render_website_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/>
    </svg>
    """
  end

  defp render_linkedin_icon do
    """
    <svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z" clip-rule="evenodd"/>
    </svg>
    """
  end

  defp render_github_icon do
    """
    <svg class="w-4 h-4 text-gray-700" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"/>
    </svg>
    """
  end

  defp render_twitter_icon do
    """
    <svg class="w-4 h-4 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
      <path d="M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.616 11.616 0 006.29 1.84"/>
    </svg>
    """
  end

  defp render_link_icon do
    """
    <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
    </svg>
    """
  end

  # ============================================================================
  # DEBUGGING AND LOGGING HELPERS
  # ============================================================================

  defp log_safe(message) when is_binary(message) do
    IO.puts("🔒 SAFE: " <> message)
  end

  defp log_safe(message) do
    IO.puts("🔒 SAFE: " <> inspect(message))
  end

  defp log_error_safe(error, context \\ "") do
    context_str = if context != "", do: " [" <> context <> "]", else: ""
    IO.puts("❌ SAFE ERROR" <> context_str <> ": " <> inspect(error))
  end

  # ============================================================================
  # FINAL SAFETY NET - Emergency Fallback Renderer
  # ============================================================================

  def emergency_render_fallback(section) do
    try do
      section_type = safe_extract(section.section_type)
      section_title = safe_extract(section.title)

      html = "<div class=\"emergency-fallback bg-yellow-50 rounded-lg p-4\">"
      html = html <> "<div class=\"flex items-center text-yellow-800 mb-2\">"
      html = html <> "<svg class=\"w-5 h-5 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.464 0L4.732 16.5c-.77.833.192 2.5 1.732 2.5z\"/>"
      html = html <> "</svg>"
      html = html <> "<span class=\"font-semibold text-sm\">Emergency Fallback Mode</span>"
      html = html <> "</div>"
      html = html <> "<h3 class=\"text-md font-medium text-yellow-900 mb-1\">" <> safe_html_escape(section_title) <> "</h3>"
      html = html <> "<p class=\"text-yellow-700 text-sm\">Section type: " <> safe_html_escape(section_type) <> "</p>"
      html = html <> "<p class=\"text-yellow-700 mt-1 text-sm\">This section is temporarily displayed in safe mode due to a rendering issue.</p>"
      html = html <> "</div>"
      html
    rescue
      _final_error ->
        # Absolute last resort - completely static HTML
        """
        <div class="absolute-fallback bg-red-50 rounded-lg p-4">
          <div class="text-red-800 font-semibold mb-1 text-sm">Critical Rendering Error</div>
          <p class="text-red-700 text-sm">Unable to render this section safely. Please contact support.</p>
        </div>
        """
    end
  end

  # ============================================================================
  # VALIDATION HELPERS
  # ============================================================================

  defp validate_content_structure(content) when is_map(content) do
    # Basic validation to ensure content has expected structure
    true
  end
  defp validate_content_structure(_), do: false

  defp validate_section_type(section_type) do
    valid_types = [
      "experience", "work_experience", "skills", "education",
      "projects", "contact", "intro", "about", "story", "hero",
      "summary", "profile", "portfolio", "work", "certifications",
      "achievements", "awards", "generic"
    ]

    clean_type = safe_extract(section_type)
    clean_type in valid_types or true  # Allow unknown types to fall through to generic
  end

end
